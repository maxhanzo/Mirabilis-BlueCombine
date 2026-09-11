//
//  FileTransferViewModel.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 04/09/26.
//

import Combine
import CoreBluetooth
import Foundation
import OSLog

@MainActor
final class FileTransferViewModel: ObservableObject {

    // MARK: - Dependencies

    private let bluetoothManager:
        BluetoothManaging

    private let fileTransferService:
        FileTransferService

    private let connectionController:
        BluetoothConnectionController

    private var cancellables =
        Set<AnyCancellable>()

    // MARK: - Device

    let device: BluetoothDevice

    // MARK: - Statistics

    @Published
    private(set) var totalUploadedBytes:
        UInt64?

    @Published
    private(set) var
        isReadingTotalUploadedBytes = false

    // MARK: - File Selection

    @Published
    private(set) var selectedFile:
        SelectedFile?

    // MARK: - Download Export

    @Published
    private(set) var downloadedData:
        Data?

    @Published
    var isFileExporterPresented = false

    let defaultDownloadFilename =
        "mirabilis_download.bin"

    // MARK: - Transfer

    @Published
    private(set) var transferState:
        FileTransferState = .idle

    @Published
    private(set) var errorMessage:
        String?

    private var hasLoaded = false

    @Published
    private(set) var isConnected: Bool

    init(
        device: BluetoothDevice,
        bluetoothManager:
            BluetoothManaging,
        connectionController:
            BluetoothConnectionController
    ) {
        self.device = device

        self.bluetoothManager =
            bluetoothManager

        self.connectionController =
            connectionController

        self.isConnected =
            connectionController.isConnected

        let fileTransferService =
            FileTransferService(
                bluetoothManager:
                    bluetoothManager
            )

        self.fileTransferService =
            fileTransferService

        bindConnectionState()
        bindFileTransferState()
        bindBluetoothEvents()

        AppLogger.ui.debug(
            "FileTransferViewModel initialized for \(device.displayName, privacy: .public)"
        )
    }
}

// MARK: - Connection State Binding

private extension FileTransferViewModel {

    func bindConnectionState() {
        connectionController.$state
            .map { state in
                if case .connected = state {
                    return true
                }

                return false
            }
            .removeDuplicates()
            .sink { [weak self] isConnected in
                self?.isConnected =
                    isConnected
            }
            .store(in: &cancellables)
    }
}

// MARK: - Presentation

extension FileTransferViewModel {

    var totalUploadedBytesText:
        String {
        guard let totalUploadedBytes else {
            return "Not read"
        }

        return """
        \(totalUploadedBytes.formatted()) bytes
        """
    }

    var hasSelectedFile: Bool {
        selectedFile != nil
    }

    var canChooseFile: Bool {
        isConnected &&
        !transferState.isTransferring
    }

    var canReadStatistics: Bool {
        isConnected &&
        !isReadingTotalUploadedBytes &&
        !transferState.isTransferring
    }

    var canUpload: Bool {
        isConnected &&
        selectedFile != nil &&
        !transferState.isTransferring
    }

    var canDownload: Bool {
        isConnected &&
        !transferState.isTransferring
    }

    var canCancel: Bool {
        isConnected &&
        transferState.isTransferring
    }

    var uploadProgress: Double? {
        guard case let .uploading(
            bytesTransferred,
            totalBytes
        ) = transferState,
        totalBytes > 0 else {
            return nil
        }

        return Double(bytesTransferred) /
            Double(totalBytes)
    }

    var uploadProgressText: String? {
        guard case let .uploading(
            bytesTransferred,
            totalBytes
        ) = transferState else {
            return nil
        }

        return """
        \(bytesTransferred.formatted()) / \
        \(totalBytes.formatted()) bytes
        """
    }

    var transferStatusText: String? {
        switch transferState {

        case .idle:
            if !isConnected {
                return "Bluetooth disconnected"
            }

            return nil

        case .preparingUpload:
            return "Preparing upload…"

        case .uploading:
            return uploadProgressText

        case .preparingDownload:
            return "Preparing download…"

        case .downloading(
            let bytesTransferred
        ):
            return """
            \(bytesTransferred.formatted()) \
            bytes downloaded
            """

        case .completed(
            .upload(
                let bytesTransferred
            )
        ):
            return """
            Upload completed — \
            \(bytesTransferred.formatted()) bytes
            """

        case .completed(
            .download(
                let bytesTransferred
            )
        ):
            return """
            Download completed — \
            \(bytesTransferred.formatted()) bytes
            """

        case .cancelled:
            return "Transfer cancelled"

        case .failed(let error):
            return error.localizedDescription
        }
    }

    var downloadedDocument:
        DownloadedFileDocument? {
        guard let downloadedData else {
            return nil
        }

        return DownloadedFileDocument(
            data: downloadedData
        )
    }
}

// MARK: - Lifecycle / Statistics

extension FileTransferViewModel {

    func load() {
        guard !hasLoaded else {
            return
        }

        hasLoaded = true

        guard isConnected else {
            return
        }

        readTotalUploadedBytes()
    }

    func readTotalUploadedBytes() {
        guard isConnected else {
            handleNotConnected()
            return
        }

        guard !isReadingTotalUploadedBytes else {
            return
        }

        errorMessage = nil
        isReadingTotalUploadedBytes = true

        bluetoothManager.read(
            .totalUploadedBytes
        )
    }
}

// MARK: - File Selection

extension FileTransferViewModel {

    func selectFile(
        at url: URL
    ) {
        errorMessage = nil

        let didStartAccessing =
            url.startAccessingSecurityScopedResource()

        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let resourceValues =
                try url.resourceValues(
                    forKeys: [
                        .fileSizeKey,
                        .isRegularFileKey
                    ]
                )

            guard resourceValues
                .isRegularFile == true else {
                throw FileSelectionError
                    .notARegularFile
            }

            if let fileSize =
                resourceValues.fileSize {

                guard fileSize > 0 else {
                    throw FileSelectionError
                        .emptyFile
                }

                guard fileSize <=
                        FileTransferProtocol
                            .maximumFileSize else {
                    throw FileSelectionError
                        .fileTooLarge
                }
            }

            let data = try Data(
                contentsOf: url
            )

            guard !data.isEmpty else {
                throw FileSelectionError
                    .emptyFile
            }

            guard data.count <=
                    FileTransferProtocol
                        .maximumFileSize else {
                throw FileSelectionError
                    .fileTooLarge
            }

            selectedFile =
                SelectedFile(
                    name:
                        url.lastPathComponent,
                    data: data
                )

            AppLogger.ui.info(
                "Selected file: \(url.lastPathComponent, privacy: .public), \(data.count) bytes"
            )

        } catch let error
            as FileSelectionError {

            selectedFile = nil
            errorMessage =
                error.localizedDescription

        } catch {
            selectedFile = nil
            errorMessage =
                "Unable to read the selected file."

            AppLogger.ui.error(
                "Unable to read selected file: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func handleFileImporterError(
        _ error: Error
    ) {
        errorMessage =
            error.localizedDescription
    }

    func handleFileExporterResult(
        _ result: Result<URL, Error>
    ) {
        switch result {

        case .success(let url):
            AppLogger.ui.info(
                "Downloaded file exported to \(url.lastPathComponent, privacy: .public)"
            )

        case .failure(let error):
            errorMessage =
                error.localizedDescription
        }
    }
}

// MARK: - Transfer Actions

extension FileTransferViewModel {

    func uploadSelectedFile() {
        guard isConnected else {
            handleNotConnected()
            return
        }

        guard let selectedFile else {
            return
        }

        errorMessage = nil
        downloadedData = nil

        do {
            try fileTransferService.upload(
                selectedFile.data
            )

        } catch let error
            as FileTransferError {

            transferState =
                .failed(error)

            errorMessage =
                error.localizedDescription

        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    func downloadFile() {
        guard isConnected else {
            handleNotConnected()
            return
        }

        errorMessage = nil
        downloadedData = nil

        do {
            try fileTransferService
                .download()

        } catch let error
            as FileTransferError {

            transferState =
                .failed(error)

            errorMessage =
                error.localizedDescription

        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    func cancelTransfer() {
        guard isConnected else {
            handleNotConnected()
            return
        }

        fileTransferService.cancel()
    }
}

// MARK: - File Transfer State Binding

private extension FileTransferViewModel {

    func bindFileTransferState() {
        fileTransferService.states
            .sink { [weak self] state in
                self?.handleFileTransferState(
                    state
                )
            }
            .store(in: &cancellables)
    }

    func handleFileTransferState(
        _ state: FileTransferState
    ) {
        transferState = state

        switch state {

        case .completed(.upload):
            if isConnected {
                readTotalUploadedBytes()
            }

        case .completed(.download):
            downloadedData =
                fileTransferService.downloadedData

            if downloadedData != nil {
                isFileExporterPresented =
                    true
            }

        case .failed(let error):
            errorMessage =
                error.localizedDescription

        default:
            break
        }
    }
}

// MARK: - Bluetooth Event Bindings

private extension FileTransferViewModel {

    func bindBluetoothEvents() {
        bindConnections()
        bindDisconnections()
        bindTotalUploadedBytesUpdates()
        bindErrors()
    }

    func bindConnections() {
        bluetoothManager.events
            .compactMap { event -> BluetoothDevice? in
                guard case .connected(let device) = event else {
                    return nil
                }

                return device
            }
            .sink { [weak self] connectedDevice in
                guard let self,
                      connectedDevice.id == device.id else {
                    return
                }

                errorMessage = nil

                if hasLoaded {
                    readTotalUploadedBytes()
                }
            }
            .store(in: &cancellables)
    }

    func bindDisconnections() {
        bluetoothManager.events
            .compactMap { event -> UUID? in
                guard case .disconnected(let deviceID) = event else {
                    return nil
                }

                return deviceID
            }
            .sink { [weak self] deviceID in
                guard let self,
                      deviceID == device.id else {
                    return
                }

                isReadingTotalUploadedBytes =
                    false

                if !transferState.isTransferring {
                    errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }

    func bindTotalUploadedBytesUpdates() {
        bluetoothManager.events
            .compactMap { event -> Data? in
                guard case .valueUpdated(
                    characteristic: .totalUploadedBytes,
                    data: let data
                ) = event else {
                    return nil
                }

                return data
            }
            .sink { [weak self] data in
                self?.handleTotalUploadedBytes(
                    data
                )
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

// MARK: - Bluetooth Errors

private extension FileTransferViewModel {

    func handleBluetoothError(
        _ error: BluetoothError
    ) {
        let wasReadingTotalUploadedBytes =
            isReadingTotalUploadedBytes

        if wasReadingTotalUploadedBytes {
            isReadingTotalUploadedBytes =
                false
        }

        switch error {

        case .notConnected:
            handleNotConnected()

        default:
            /*
             FileTransferService owns transfer-related
             Bluetooth errors. Only surface unrelated
             BLE errors here when this feature initiated
             a statistics read.
             */
            if wasReadingTotalUploadedBytes {
                errorMessage =
                    error.localizedDescription
            }
        }
    }

    func handleNotConnected() {
        isReadingTotalUploadedBytes =
            false

        errorMessage =
            "Connect to the device before using file transfer."
    }
}

// MARK: - Total Uploaded Bytes Decoding

private extension FileTransferViewModel {

    func handleTotalUploadedBytes(
        _ data: Data
    ) {
        isReadingTotalUploadedBytes =
            false

        guard let value =
                decodeUInt64LittleEndian(
                    from: data
                ) else {
            errorMessage =
                """
                Invalid Total Uploaded Bytes \
                response.
                """

            return
        }

        totalUploadedBytes = value
    }

    func decodeUInt64LittleEndian(
        from data: Data
    ) -> UInt64? {
        guard data.count >= 8 else {
            return nil
        }

        var value: UInt64 = 0

        for (index, byte) in
            data.prefix(8).enumerated() {

            value |=
                UInt64(byte) <<
                UInt64(index * 8)
        }

        return value
    }
}

