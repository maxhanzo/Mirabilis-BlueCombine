//
//  BluetoothError.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import CoreBluetooth
import Foundation

enum BluetoothError: LocalizedError, Equatable {

    case bluetoothUnavailable(
        BluetoothState.Availability
    )

    case deviceNotFound(UUID)

    case connectionFailed(
        deviceID: UUID,
        reason: String?
    )

    case disconnected(
        deviceID: UUID,
        reason: String?
    )

    case notConnected

    case serviceDiscoveryFailed(String)

    case characteristicDiscoveryFailed(String)

    case characteristicNotFound(
        MirabilisUUID.Characteristic
    )

    case unsupportedOperation(
        MirabilisUUID.Characteristic
    )

    case readFailed(
        MirabilisUUID.Characteristic,
        reason: String
    )

    case writeFailed(
        MirabilisUUID.Characteristic,
        reason: String
    )

    case notificationFailed(
        MirabilisUUID.Characteristic,
        reason: String
    )

    var errorDescription: String? {
        switch self {

        case .bluetoothUnavailable(let availability):
            return """
            Bluetooth is unavailable \
            (\(String(describing: availability))).
            """

        case .deviceNotFound:
            return "The Bluetooth device could not be found."

        case let .connectionFailed(_, reason):
            return reason.map {
                "Unable to connect to the device: \($0)"
            } ?? "Unable to connect to the device."

        case let .disconnected(_, reason):
            return reason.map {
                "The Bluetooth device disconnected: \($0)"
            } ?? "The Bluetooth device disconnected."

        case .notConnected:
            return "No Bluetooth device is connected."

        case .serviceDiscoveryFailed(let reason):
            return """
            Service discovery failed: \(reason)
            """

        case .characteristicDiscoveryFailed(let reason):
            return """
            Characteristic discovery failed: \(reason)
            """

        case .characteristicNotFound(let characteristic):
            return """
            Characteristic not found: \
            \(characteristic.uuid.uuidString)
            """

        case .unsupportedOperation(let characteristic):
            return """
            Unsupported operation for characteristic: \
            \(characteristic.uuid.uuidString)
            """

        case let .readFailed(characteristic, reason):
            return """
            Read failed for \
            \(characteristic.uuid.uuidString): \(reason)
            """

        case let .writeFailed(characteristic, reason):
            return """
            Write failed for \
            \(characteristic.uuid.uuidString): \(reason)
            """

        case let .notificationFailed(characteristic, reason):
            return """
            Notification configuration failed for \
            \(characteristic.uuid.uuidString): \(reason)
            """
        }
    }
}
