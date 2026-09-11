//
//  BluetoothManager+CBPeripheralDelegate.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import CoreBluetooth
import Foundation
import OSLog

extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error {
            AppLogger.bluetooth.error(
                "Service discovery failed: \(error.localizedDescription, privacy: .public)"
            )

            emit(
                .error(
                    .serviceDiscoveryFailed(
                        error.localizedDescription
                    )
                )
            )

            return
        }

        let services = Set(
            peripheral.services?
                .compactMap {
                    MirabilisUUID.Service(
                        uuid: $0.uuid
                    )
                } ?? []
        )

        AppLogger.bluetooth.debug(
            "Discovered \(services.count) known service(s)"
        )

        emit(
            .servicesDiscovered(services)
        )

        peripheral.services?.forEach { service in

            guard let knownService =
                    MirabilisUUID.Service(
                        uuid: service.uuid
                    )
            else {
                AppLogger.bluetooth.debug(
                    "Ignoring unknown service \(service.uuid.uuidString, privacy: .public)"
                )

                return
            }

            let characteristicUUIDs =
                MirabilisUUID.Characteristic
                    .allCases
                    .filter {
                        $0.service == knownService
                    }
                    .map(\.uuid)

            AppLogger.bluetooth.debug(
                "Discovering \(characteristicUUIDs.count) characteristic(s) for \(String(describing: knownService), privacy: .public)"
            )

            peripheral.discoverCharacteristics(
                characteristicUUIDs,
                for: service
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            AppLogger.bluetooth.error(
                "Characteristic discovery failed for service \(service.uuid.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )

            emit(
                .error(
                    .characteristicDiscoveryFailed(
                        error.localizedDescription
                    )
                )
            )

            return
        }

        let characteristics = Set(
            service.characteristics?
                .compactMap {
                    MirabilisUUID.Characteristic(
                        uuid: $0.uuid
                    )
                } ?? []
        )

        service.characteristics?.forEach {
            guard let characteristic =
                    MirabilisUUID.Characteristic(
                        uuid: $0.uuid
                    )
            else {
                AppLogger.bluetooth.debug(
                    "Ignoring unknown characteristic \($0.uuid.uuidString, privacy: .public)"
                )

                return
            }

            discoveredCharacteristics[
                characteristic
            ] = $0
        }

        AppLogger.bluetooth.debug(
            "Discovered \(characteristics.count) known characteristic(s) for service \(service.uuid.uuidString, privacy: .public)"
        )

        emit(
            .characteristicsDiscovered(
                characteristics
            )
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let knownCharacteristic =
                MirabilisUUID.Characteristic(
                    uuid: characteristic.uuid
                )
        else {
            AppLogger.bluetooth.debug(
                "Received value for unknown characteristic \(characteristic.uuid.uuidString, privacy: .public)"
            )

            return
        }

        if let error {
            AppLogger.bluetooth.error(
                "VALUE failed ← \(String(describing: knownCharacteristic), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )

            emit(
                .error(
                    .readFailed(
                        knownCharacteristic,
                        reason: error.localizedDescription
                    )
                )
            )

            return
        }

        guard let data = characteristic.value else {
            AppLogger.bluetooth.warning(
                "VALUE ← \(String(describing: knownCharacteristic), privacy: .public) returned no data"
            )

            return
        }

        AppLogger.bluetooth.debug(
            "VALUE ← \(String(describing: knownCharacteristic), privacy: .public) [\(data.count) bytes]"
        )

        emit(
            .valueUpdated(
                characteristic: knownCharacteristic,
                data: data
            )
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let knownCharacteristic =
                MirabilisUUID.Characteristic(
                    uuid: characteristic.uuid
                )
        else {
            AppLogger.bluetooth.debug(
                "Received write result for unknown characteristic \(characteristic.uuid.uuidString, privacy: .public)"
            )

            return
        }

        if let error {
            AppLogger.bluetooth.error(
                "WRITE failed ← \(String(describing: knownCharacteristic), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )

            emit(
                .error(
                    .writeFailed(
                        knownCharacteristic,
                        reason: error.localizedDescription
                    )
                )
            )

            return
        }

        AppLogger.bluetooth.debug(
            "WRITE completed ← \(String(describing: knownCharacteristic), privacy: .public)"
        )

        emit(
            .writeCompleted(
                characteristic: knownCharacteristic
            )
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let knownCharacteristic =
                MirabilisUUID.Characteristic(
                    uuid: characteristic.uuid
                )
        else {
            AppLogger.bluetooth.debug(
                "Received notification state for unknown characteristic \(characteristic.uuid.uuidString, privacy: .public)"
            )

            return
        }

        if let error {
            AppLogger.bluetooth.error(
                "NOTIFY failed ← \(String(describing: knownCharacteristic), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )

            emit(
                .error(
                    .notificationFailed(
                        knownCharacteristic,
                        reason: error.localizedDescription
                    )
                )
            )

            return
        }

        AppLogger.bluetooth.debug(
            "NOTIFY \(characteristic.isNotifying ? "ON" : "OFF", privacy: .public) ← \(String(describing: knownCharacteristic), privacy: .public)"
        )

        emit(
            .notificationStateChanged(
                characteristic: knownCharacteristic,
                isEnabled: characteristic.isNotifying
            )
        )
    }
}
