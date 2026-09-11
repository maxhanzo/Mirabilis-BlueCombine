//
//  FileTransferProtocol.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//
import Foundation

nonisolated enum FileTransferProtocol {

    static let maximumFileSize = 16_384
    static let maximumPacketSize = 20
    static let maximumPayloadSize = 18
    static let acknowledgementInterval = 8

    enum Marker: UInt8 {
        case start = 0x02       // STR
        case end = 0x03         // ETX
    }

    enum Control: UInt8 {
        case acknowledge = 0x06
        case negativeAcknowledge = 0x15
        case cancel = 0x18
    }

    enum Command: UInt8 {
        case upload = 0x55      // "U"
        case download = 0x44    // "D"
    }
}

// MARK: - Encoding

extension FileTransferProtocol {

    static func makeUploadCommand(
        fileSize: Int
    ) -> Data {
        precondition(
            fileSize > 0 &&
            fileSize <= maximumFileSize,
            "Invalid upload file size."
        )

        let size = UInt32(fileSize)

        return Data([
            Command.upload.rawValue,
            UInt8(truncatingIfNeeded: size),
            UInt8(truncatingIfNeeded: size >> 8),
            UInt8(truncatingIfNeeded: size >> 16),
            UInt8(truncatingIfNeeded: size >> 24)
        ])
    }

    static func makeUploadChunks(
        from data: Data
    ) -> [FileTransferChunk] {
        guard !data.isEmpty else {
            return []
        }

        var chunks: [FileTransferChunk] = []

        chunks.reserveCapacity(
            (data.count + maximumPayloadSize - 1)
            / maximumPayloadSize
        )

        var offset = 0
        var sequence: UInt8 = 0

        while offset < data.count {
            let end = min(
                offset + maximumPayloadSize,
                data.count
            )

            let payload = data[offset..<end]
            let isFinalChunk = end == data.count

            chunks.append(
                FileTransferChunk(
                    marker: isFinalChunk ? .end : .start,
                    sequence: sequence,
                    payload: Data(payload)
                )
            )

            offset = end
            sequence &+= 1
        }

        return chunks
    }
}
