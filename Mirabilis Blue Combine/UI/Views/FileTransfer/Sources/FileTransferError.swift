//
//  FileTransferError.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//
import Foundation

enum FileTransferError: LocalizedError, Equatable {

    case fileTooLarge(
        actual: Int,
        maximum: Int
    )

    case emptyFile
    case payloadTooLarge
    case malformedPacket

    case unexpectedSequence(
        expected: UInt8,
        received: UInt8
    )

    case negativeAcknowledgement(UInt8?)
    case timeout
    case disconnected
    case transferAlreadyInProgress
    case bluetooth(BluetoothError)

    var errorDescription: String? {
        switch self {

        case let .fileTooLarge(actual, maximum):
            return "File is too large for transfer (\(actual) bytes; maximum is \(maximum) bytes)."

        case .emptyFile:
            return "The selected file is empty."

        case .payloadTooLarge:
            return "A file-transfer payload exceeded the maximum chunk size."

        case .malformedPacket:
            return "A malformed file-transfer packet was received."

        case let .unexpectedSequence(expected, received):
            return "Unexpected sequence number. Expected \(expected), received \(received)."

        case let .negativeAcknowledgement(sequence):
            if let sequence {
                return "The peripheral rejected the transfer batch ending at sequence \(sequence)."
            }

            return "The peripheral rejected the transfer batch."

        case .timeout:
            return "The file transfer timed out."

        case .disconnected:
            return "The device disconnected during the file transfer."

        case .transferAlreadyInProgress:
            return "A file transfer is already in progress."

        case let .bluetooth(error):
            return error.localizedDescription
        }
    }
}
