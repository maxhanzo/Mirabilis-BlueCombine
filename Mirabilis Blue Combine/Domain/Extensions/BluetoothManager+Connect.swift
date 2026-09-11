//
//  BluetoothManager+Connect.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import CoreBluetooth
import Dispatch
import Foundation
import OSLog

extension BluetoothManager {

    func connect(to device: BluetoothDevice) {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard let peripheral =
                    self.discoveredPeripherals[device.id] else {

                AppLogger.bluetooth.error(
                    "Connection requested for unknown device \(device.id.uuidString, privacy: .public)"
                )

                self.emit(
                    .error(
                        .deviceNotFound(device.id)
                    )
                )

                return
            }

            AppLogger.bluetooth.debug(
                "Connecting to \(device.displayName, privacy: .public) [\(device.id.uuidString, privacy: .public)]"
            )

            self.centralManager.stopScan()

            self.state.activity =
                .connecting(device.id)

            self.emit(
                .stateChanged(self.state)
            )

            self.centralManager.connect(
                peripheral,
                options: nil
            )
        }
    }

    func disconnect() {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }

            guard let peripheral =
                    self.connectedPeripheral else {

                AppLogger.bluetooth.debug(
                    "Disconnect requested with no connected peripheral"
                )

                return
            }

            AppLogger.bluetooth.debug(
                "Disconnecting from \(peripheral.name ?? "Unknown Device", privacy: .public) [\(peripheral.identifier.uuidString, privacy: .public)]"
            )

            self.state.activity =
                .disconnecting(
                    peripheral.identifier
                )

            self.emit(
                .stateChanged(self.state)
            )

            self.centralManager
                .cancelPeripheralConnection(
                    peripheral
                )
        }
    }
}
