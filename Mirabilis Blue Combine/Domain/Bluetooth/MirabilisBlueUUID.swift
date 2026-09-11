//
//  MirabilisBlueUUID.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import CoreBluetooth

nonisolated enum MirabilisDevice {
    static let advertisedName =
        "BLE-MIRABILIS-BLUE"
}

nonisolated enum MirabilisUUID {
    private static let customPrefix =
        "7E57A000-0000-4B1A-9C00-00000000"

    enum Service: CaseIterable, Hashable, Sendable {
        case deviceInformation
        case tutorial

        var uuid: CBUUID {
            switch self {

            case .deviceInformation:
                return CBUUID(string: "180A")

            case .tutorial:
                return CBUUID(
                    string: "\(MirabilisUUID.customPrefix)0001"
                )
            }
        }

        init?(uuid: CBUUID) {
            guard let service = Self.allCases.first(
                where: { $0.uuid == uuid }
            ) else {
                return nil
            }

            self = service
        }
    }

    enum Characteristic: CaseIterable, Hashable, Sendable {
        // Device Information Service
        case serialNumber
        case hardwareRevision
        case firmwareRevision

        // Custom Tutorial Service
        case basicWrite
        case lastWrittenValue

        case observableWrite
        case observableValue

        case periodicEventStream

        case writeWithoutResponse
        case lastWriteWithoutResponseValue

        case secureWrite
        case secureState

        case fileTransferRX
        case fileTransferTX

        case totalUploadedBytes

        var uuid: CBUUID {
            switch self {

            case .serialNumber:
                return CBUUID(string: "2A25")

            case .hardwareRevision:
                return CBUUID(string: "2A27")

            case .firmwareRevision:
                return CBUUID(string: "2A26")

            case .basicWrite:
                return customUUID(suffix: "0002")

            case .lastWrittenValue:
                return customUUID(suffix: "0003")

            case .observableWrite:
                return customUUID(suffix: "0004")

            case .observableValue:
                return customUUID(suffix: "0005")

            case .periodicEventStream:
                return customUUID(suffix: "0006")

            case .writeWithoutResponse:
                return customUUID(suffix: "0007")

            case .lastWriteWithoutResponseValue:
                return customUUID(suffix: "0008")

            case .secureWrite:
                return customUUID(suffix: "0009")

            case .secureState:
                return customUUID(suffix: "000A")

            case .fileTransferRX:
                return customUUID(suffix: "000B")

            case .fileTransferTX:
                return customUUID(suffix: "000C")

            case .totalUploadedBytes:
                return customUUID(suffix: "000E")
            }
        }

        var service: Service {
            switch self {
            case .serialNumber,
                 .hardwareRevision,
                 .firmwareRevision:
                return .deviceInformation

            default:
                return .tutorial
            }
        }

        var supportsRead: Bool {
            switch self {
            case .serialNumber,
                 .hardwareRevision,
                 .firmwareRevision,
                 .lastWrittenValue,
                 .observableValue,
                 .lastWriteWithoutResponseValue,
                 .secureState,
                 .totalUploadedBytes:
                return true

            default:
                return false
            }
        }

        var supportsNotifications: Bool {
            switch self {
            case .observableValue,
                 .periodicEventStream,
                 .secureState,
                 .fileTransferTX:
                return true

            default:
                return false
            }
        }

        var writeType: CBCharacteristicWriteType? {
            switch self {

            case .basicWrite,
                 .observableWrite,
                 .secureWrite:
                return .withResponse

            case .writeWithoutResponse,
                 .fileTransferRX:
                return .withoutResponse

            default:
                return nil
            }
        }

        init?(uuid: CBUUID) {
            guard let characteristic = Self.allCases.first(
                where: { $0.uuid == uuid }
            ) else {
                return nil
            }

            self = characteristic
        }

        private func customUUID(suffix: String) -> CBUUID {
            CBUUID(
                string: "\(MirabilisUUID.customPrefix)\(suffix)" // Main actor-isolated static property 'customPrefix' can not be referenced from a nonisolated context
            )
        }
    }
}
