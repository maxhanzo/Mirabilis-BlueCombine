//
//  FileTransferService.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Combine
import Foundation
import OSLog

final class FileTransferService {

    private struct UploadContext {
        let chunks: [FileTransferChunk]
        let totalBytes: Int

        var nextChunkIndex = 0
        var lastBatchStartIndex: Int?
        var lastBatchEndIndex: Int?
        var acknowledgedBytes = 0
        var hasStartedTransmission = false
    }

    private struct DownloadContext {
        var data = Data()
        var expectedSequence: UInt8 = 0
        var chunksSinceLastAcknowledgement = 0
        var hasStartedTransmission = false
    }

    private let bluetoothManager: BluetoothManaging

    private var cancellables =
        Set<AnyCancellable>()

    private let stateSubject =
        CurrentValueSubject<FileTransferState, Never>(.idle)

    var states: AnyPublisher<FileTransferState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    private var uploadContext: UploadContext?
    private var downloadContext: DownloadContext?

    private(set) var downloadedData: Data?

    private(set) var state:
        FileTransferState = .idle {
        didSet {
            guard oldValue != state else {
                return
            }

            stateSubject.send(state)
        }
    }

    init(
        bluetoothManager: BluetoothManaging
    ) {
        self.bluetoothManager = bluetoothManager

        bindBluetoothEvents()

        AppLogger.fileTransfer.debug(
            "FileTransferService initialized"
        )
    }

    deinit {
        AppLogger.fileTransfer.debug(
            "FileTransferService deinitialized"
        )
    }
}

// MARK: - Operations

extension FileTransferService {

    func upload(
        _ data: Data
    ) throws {
        guard !state.isTransferring else {
            throw FileTransferError
                .transferAlreadyInProgress
        }

        guard !data.isEmpty else {
            throw FileTransferError.emptyFile
        }

        guard data.count <=
                FileTransferProtocol.maximumFileSize else {

            throw FileTransferError.fileTooLarge(
                actual: data.count,
                maximum:
                    FileTransferProtocol.maximumFileSize
            )
        }

        let chunks =
            FileTransferProtocol.makeUploadChunks(
                from: data
            )

        guard !chunks.isEmpty else {
            throw FileTransferError.emptyFile
        }

        downloadedData = nil
        downloadContext = nil

        uploadContext = UploadContext(
            chunks: chunks,
            totalBytes: data.count
        )

        AppLogger.fileTransfer.info(
            "Preparing upload: \(data.count) bytes, \(chunks.count) chunks"
        )

        state = .preparingUpload

        bluetoothManager.setNotifications(
            true,
            for: .fileTransferTX
        )
    }

    func download() throws {
        guard !state.isTransferring else {
            throw FileTransferError
                .transferAlreadyInProgress
        }

        uploadContext = nil
        downloadedData = nil
        downloadContext = DownloadContext()

        AppLogger.fileTransfer.info(
            "Preparing download"
        )

        state = .preparingDownload

        // Download chunks arrive asynchronously on TX,
        // so subscribe before sending the D command.
        bluetoothManager.setNotifications(
            true,
            for: .fileTransferTX
        )
    }

    func cancel() {
        guard state.isTransferring else {
            return
        }

        AppLogger.fileTransfer.info(
            "Cancelling file transfer"
        )

        bluetoothManager.write(
            Data([
                FileTransferProtocol
                    .Control
                    .cancel
                    .rawValue
            ]),
            to: .fileTransferRX
        )

        clearTransferContexts()
        state = .cancelled
    }
}

// MARK: - Bluetooth Event Bindings

private extension FileTransferService {

    func bindBluetoothEvents() {
        bindFileTransferTXNotificationState()
        bindIncomingTransferData()
        bindDisconnections()
        bindErrors()
    }

    func bindFileTransferTXNotificationState() {
        bluetoothManager.events
            .compactMap { event -> Bool? in
                guard case .notificationStateChanged(
                    characteristic: .fileTransferTX,
                    isEnabled: let isEnabled
                ) = event else {
                    return nil
                }

                return isEnabled
            }
            .sink { [weak self] isEnabled in
                self?.handleFileTransferTXNotificationState(
                    isEnabled: isEnabled
                )
            }
            .store(in: &cancellables)
    }

    func bindIncomingTransferData() {
        bluetoothManager.events
            .compactMap { event -> Data? in
                guard case .valueUpdated(
                    characteristic: .fileTransferTX,
                    data: let data
                ) = event else {
                    return nil
                }

                return data
            }
            .sink { [weak self] data in
                self?.handleIncomingTransferData(
                    data
                )
            }
            .store(in: &cancellables)
    }

    func bindDisconnections() {
        bluetoothManager.events
            .compactMap { event -> Void? in
                guard case .disconnected = event else {
                    return nil
                }

                return ()
            }
            .sink { [weak self] in
                self?.handleDisconnect()
            }
            .store(in: &cancellables)
    }

    func bindErrors() {
        bluetoothManager.events
            .compactMap { event -> BluetoothError? in
                guard case .error(let error) = event else {
                    return nil
                }

                return error
            }
            .sink { [weak self] error in
                self?.handleBluetoothError(
                    error
                )
            }
            .store(in: &cancellables)
    }
}

// MARK: - TX Notification State

private extension FileTransferService {

    func handleFileTransferTXNotificationState(
        isEnabled: Bool
    ) {
        guard isEnabled else {
            return
        }

        switch state {

        case .preparingUpload:
            startUploadTransmission()

        case .preparingDownload:
            startDownloadTransmission()

        default:
            break
        }
    }
}

// MARK: - Upload Startup

private extension FileTransferService {

    func startUploadTransmission() {
        guard var context = uploadContext else {
            fail(.malformedPacket)
            return
        }

        guard !context.hasStartedTransmission else {
            return
        }

        context.hasStartedTransmission = true
        uploadContext = context

        let command =
            FileTransferProtocol.makeUploadCommand(
                fileSize: context.totalBytes
            )

        AppLogger.fileTransfer.debug(
            "TX → upload command [\(command.count) bytes]"
        )

        bluetoothManager.write(
            command,
            to: .fileTransferRX
        )

        state = .uploading(
            bytesTransferred: 0,
            totalBytes: context.totalBytes
        )

        sendNextUploadBatch()
    }
}

// MARK: - Upload Batches

private extension FileTransferService {

    func sendNextUploadBatch() {
        guard var context = uploadContext else {
            fail(.malformedPacket)
            return
        }

        guard context.nextChunkIndex <
                context.chunks.count else {
            return
        }

        let startIndex = context.nextChunkIndex
        let endIndex = min(
            startIndex +
                FileTransferProtocol
                    .acknowledgementInterval,
            context.chunks.count
        )

        context.lastBatchStartIndex = startIndex
        context.lastBatchEndIndex = endIndex - 1
        context.nextChunkIndex = endIndex

        uploadContext = context

        AppLogger.fileTransfer.debug(
            "Sending upload batch: chunks \(startIndex)...\(endIndex - 1)"
        )

        for index in startIndex..<endIndex {
            let chunk = context.chunks[index]

            bluetoothManager.write(
                chunk.data,
                to: .fileTransferRX
            )
        }
    }
}

// MARK: - Download Startup

private extension FileTransferService {

    func startDownloadTransmission() {
        guard var context = downloadContext else {
            fail(.malformedPacket)
            return
        }

        guard !context.hasStartedTransmission else {
            return
        }

        context.hasStartedTransmission = true
        downloadContext = context

        let command = Data([
            FileTransferProtocol
                .Command
                .download
                .rawValue
        ])

        AppLogger.fileTransfer.debug(
            "TX → download command [\(command.count) byte]"
        )

        state = .downloading(
            bytesTransferred: 0
        )

        bluetoothManager.write(
            command,
            to: .fileTransferRX
        )
    }
}

// MARK: - Incoming Transfer Data

private extension FileTransferService {

    func handleIncomingTransferData(
        _ data: Data
    ) {
        guard state.isTransferring else {
            return
        }

        switch state {

        case .uploading:
            handleIncomingUploadControl(
                data
            )

        case .preparingDownload,
             .downloading:
            handleIncomingDownloadPacket(
                data
            )

        default:
            break
        }
    }
}

// MARK: - Upload Responses

private extension FileTransferService {

    func handleIncomingUploadControl(
        _ data: Data
    ) {
        guard let controlByte = data.first else {
            fail(.malformedPacket)
            return
        }

        switch controlByte {

        case FileTransferProtocol
            .Control
            .acknowledge
            .rawValue:
            handleUploadAcknowledgement(
                data
            )

        case FileTransferProtocol
            .Control
            .negativeAcknowledge
            .rawValue:
            let sequence =
                data.count >= 2 ? data[1] : nil

            fail(
                .negativeAcknowledgement(
                    sequence
                )
            )

        case FileTransferProtocol
            .Control
            .cancel
            .rawValue:
            clearTransferContexts()
            state = .cancelled

        default:
            fail(.malformedPacket)
        }
    }

    func handleUploadAcknowledgement(
        _ data: Data
    ) {
        guard data.count >= 2 else {
            fail(.malformedPacket)
            return
        }

        guard var context = uploadContext,
              let startIndex =
                context.lastBatchStartIndex,
              let endIndex =
                context.lastBatchEndIndex
        else {
            fail(.malformedPacket)
            return
        }

        let receivedSequence = data[1]
        let expectedSequence =
            context.chunks[endIndex].sequence

        guard receivedSequence == expectedSequence else {
            fail(
                .unexpectedSequence(
                    expected: expectedSequence,
                    received: receivedSequence
                )
            )

            return
        }

        let acknowledgedPayloadBytes =
            context.chunks[startIndex...endIndex]
                .reduce(0) {
                    $0 + $1.payload.count
                }

        context.acknowledgedBytes +=
            acknowledgedPayloadBytes

        context.lastBatchStartIndex = nil
        context.lastBatchEndIndex = nil

        let isComplete =
            context.nextChunkIndex ==
            context.chunks.count

        let acknowledgedBytes =
            context.acknowledgedBytes

        let totalBytes =
            context.totalBytes

        uploadContext = context

        AppLogger.fileTransfer.debug(
            "ACK \(receivedSequence): \(acknowledgedBytes)/\(totalBytes) bytes"
        )

        state = .uploading(
            bytesTransferred: acknowledgedBytes,
            totalBytes: totalBytes
        )

        if isComplete {
            AppLogger.fileTransfer.info(
                "Upload completed: \(totalBytes) bytes"
            )

            uploadContext = nil

            state = .completed(
                .upload(
                    bytesTransferred: totalBytes
                )
            )

            return
        }

        sendNextUploadBatch()
    }
}

// MARK: - Download Packets

private extension FileTransferService {

    func handleIncomingDownloadPacket(
        _ data: Data
    ) {
        guard data.count >= 2 else {
            fail(.malformedPacket)
            return
        }

        guard let marker =
                FileTransferProtocol.Marker(
                    rawValue: data[0]
                ) else {

            handleIncomingDownloadControl(
                data
            )

            return
        }

        let sequence = data[1]
        let payload = Data(
            data.dropFirst(2)
        )

        guard payload.count <=
                FileTransferProtocol.maximumPayloadSize else {
            fail(.payloadTooLarge)
            return
        }

        guard var context = downloadContext else {
            fail(.malformedPacket)
            return
        }

        guard sequence == context.expectedSequence else {
            fail(
                .unexpectedSequence(
                    expected:
                        context.expectedSequence,
                    received: sequence
                )
            )

            return
        }

        let newSize =
            context.data.count +
            payload.count

        guard newSize <=
                FileTransferProtocol.maximumFileSize else {
            fail(
                .fileTooLarge(
                    actual: newSize,
                    maximum:
                        FileTransferProtocol.maximumFileSize
                )
            )

            return
        }

        context.data.append(
            payload
        )

        context.expectedSequence &+= 1
        context.chunksSinceLastAcknowledgement += 1

        let shouldAcknowledge =
            marker == .end ||
            context.chunksSinceLastAcknowledgement >=
                FileTransferProtocol
                    .acknowledgementInterval

        let downloadedBytes =
            context.data.count

        downloadContext = context

        state = .downloading(
            bytesTransferred: downloadedBytes
        )

        if shouldAcknowledge {
            sendDownloadAcknowledgement(
                sequence: sequence
            )

            context.chunksSinceLastAcknowledgement = 0
            downloadContext = context
        }

        guard marker == .end else {
            return
        }

        downloadedData = context.data

        AppLogger.fileTransfer.info(
            "Download completed: \(downloadedBytes) bytes"
        )

        downloadContext = nil

        state = .completed(
            .download(
                bytesTransferred: downloadedBytes
            )
        )
    }

    func handleIncomingDownloadControl(
        _ data: Data
    ) {
        guard let controlByte = data.first else {
            fail(.malformedPacket)
            return
        }

        switch controlByte {

        case FileTransferProtocol
            .Control
            .negativeAcknowledge
            .rawValue:
            let sequence =
                data.count >= 2 ? data[1] : nil

            fail(
                .negativeAcknowledgement(
                    sequence
                )
            )

        case FileTransferProtocol
            .Control
            .cancel
            .rawValue:
            clearTransferContexts()
            state = .cancelled

        default:
            fail(.malformedPacket)
        }
    }

    func sendDownloadAcknowledgement(
        sequence: UInt8
    ) {
        let acknowledgement = Data([
            FileTransferProtocol
                .Control
                .acknowledge
                .rawValue,
            sequence
        ])

        AppLogger.fileTransfer.debug(
            "TX → download ACK \(sequence)"
        )

        bluetoothManager.write(
            acknowledgement,
            to: .fileTransferRX
        )
    }
}

// MARK: - Failure Handling

private extension FileTransferService {

    func handleDisconnect() {
        guard state.isTransferring else {
            return
        }

        fail(.disconnected)
    }

    func handleBluetoothError(
        _ error: BluetoothError
    ) {
        guard state.isTransferring else {
            return
        }

        fail(
            .bluetooth(error)
        )
    }

    func fail(
        _ error: FileTransferError
    ) {
        AppLogger.fileTransfer.error(
            "File transfer failed: \(error.localizedDescription, privacy: .public)"
        )

        clearTransferContexts()
        state = .failed(error)
    }

    func clearTransferContexts() {
        uploadContext = nil
        downloadContext = nil
    }
}
