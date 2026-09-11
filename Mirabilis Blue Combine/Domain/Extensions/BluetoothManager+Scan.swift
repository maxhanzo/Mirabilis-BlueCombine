//
//  BluetoothManager+Scan.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import CoreBluetooth
import Foundation
import OSLog

extension BluetoothManager {

    func startScanning() {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }

            let centralManager = self.centralManager

            switch centralManager.state {

            case .poweredOn:
                self.shouldStartScanningWhenReady = false
                self.performScan()

            case .unknown,
                 .resetting:
                self.shouldStartScanningWhenReady = true

                AppLogger.bluetooth.debug(
                    "Bluetooth is initializing. Scan will start when ready."
                )

            case .poweredOff,
                 .unauthorized,
                 .unsupported:
                self.shouldStartScanningWhenReady = false

                self.emit(
                    .error(
                        .bluetoothUnavailable(
                            self.state.availability
                        )
                    )
                )

            @unknown default:
                self.shouldStartScanningWhenReady = false

                self.emit(
                    .error(
                        .bluetoothUnavailable(
                            self.state.availability
                        )
                    )
                )
            }
        }
    }

    func stopScanning() {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.shouldStartScanningWhenReady = false

            self.centralManager.stopScan()

            if case .scanning = self.state.activity {
                self.state.activity = .idle

                self.emit(
                    .stateChanged(self.state)
                )
            }
        }
    }
}

extension BluetoothManager {

    func performScan() {
        AppLogger.bluetooth.info(
            "performScan() called. Central state: \(String(describing: self.centralManager.state), privacy: .public)"
        )

        discoveredPeripherals.removeAll()

        state.activity = .scanning

        emit(
            .stateChanged(state)
        )

        AppLogger.bluetooth.info(
            "Calling scanForPeripherals for tutorial service"
        )

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey:
                    false
            ]
        )
    }
}
