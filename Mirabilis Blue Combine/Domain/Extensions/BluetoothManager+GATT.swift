//
//  BluetoothManager+GATT.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import CoreBluetooth
import Foundation
import OSLog

extension BluetoothManager {

    func read(
        _ characteristic: MirabilisUUID.Characteristic
    ) {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard characteristic.supportsRead else {
                self.emit(
                    .error(
                        .unsupportedOperation(
                            characteristic
                        )
                    )
                )

                return
            }

            guard let peripheral =
                    self.connectedPeripheral else {
                self.emit(
                    .error(
                        .notConnected
                    )
                )

                return
            }

            guard let cbCharacteristic =
                    self.discoveredCharacteristics[
                        characteristic
                    ] else {
                self.emit(
                    .error(
                        .characteristicNotFound(
                            characteristic
                        )
                    )
                )

                return
            }

            peripheral.readValue(
                for: cbCharacteristic
            )
        }
    }

    func write(
        _ data: Data,
        to characteristic:
            MirabilisUUID.Characteristic
    ) {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard let writeType =
                    characteristic.writeType else {
                self.emit(
                    .error(
                        .unsupportedOperation(
                            characteristic
                        )
                    )
                )

                return
            }

            guard let peripheral =
                    self.connectedPeripheral else {
                self.emit(
                    .error(
                        .notConnected
                    )
                )

                return
            }

            guard let cbCharacteristic =
                    self.discoveredCharacteristics[
                        characteristic
                    ] else {
                self.emit(
                    .error(
                        .characteristicNotFound(
                            characteristic
                        )
                    )
                )

                return
            }

            peripheral.writeValue(
                data,
                for: cbCharacteristic,
                type: writeType
            )
        }
    }

    func setNotifications(
        _ enabled: Bool,
        for characteristic:
            MirabilisUUID.Characteristic
    ) {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard characteristic
                .supportsNotifications else {
                self.emit(
                    .error(
                        .unsupportedOperation(
                            characteristic
                        )
                    )
                )

                return
            }

            guard let peripheral =
                    self.connectedPeripheral else {
                self.emit(
                    .error(
                        .notConnected
                    )
                )

                return
            }

            guard let cbCharacteristic =
                    self.discoveredCharacteristics[
                        characteristic
                    ] else {
                self.emit(
                    .error(
                        .characteristicNotFound(
                            characteristic
                        )
                    )
                )

                return
            }

            peripheral.setNotifyValue(
                enabled,
                for: cbCharacteristic
            )
        }
    }
}
