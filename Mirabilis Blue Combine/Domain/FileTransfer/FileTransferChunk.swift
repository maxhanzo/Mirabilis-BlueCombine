//
//  FileTransferChunk.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//
import Foundation

struct FileTransferChunk: Equatable, Sendable {

    let marker: FileTransferProtocol.Marker
    let sequence: UInt8
    let payload: Data

    init(
        marker: FileTransferProtocol.Marker,
        sequence: UInt8,
        payload: Data
    ) {
        precondition(
            payload.count <=
                FileTransferProtocol.maximumPayloadSize,
            "File transfer payload exceeds maximum size."
        )

        self.marker = marker
        self.sequence = sequence
        self.payload = payload
    }

    var data: Data {
        var packet = Data()

        packet.reserveCapacity(
            2 + payload.count
        )

        packet.append(marker.rawValue)
        packet.append(sequence)
        packet.append(payload)

        return packet
    }
}
