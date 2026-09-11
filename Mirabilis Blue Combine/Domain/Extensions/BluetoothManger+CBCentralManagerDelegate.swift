//
//  BluetoothManger+CBCentralManagerDelegate.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import CoreBluetooth
import Foundation
import OSLog

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        AppLogger.bluetooth.info(
            "Bluetooth state: \(String(describing: central.state), privacy: .public), pending scan: \(self.shouldStartScanningWhenReady)"
        )
        
        state.availability = map(
            central.state
        )

        AppLogger.bluetooth.info(
            "Bluetooth state changed: \(String(describing: central.state), privacy: .public)"
        )

        if central.state != .poweredOn {
            state.activity = .idle
        }

        emit(
            .stateChanged(state)
        )

        if central.state == .poweredOn,
           shouldStartScanningWhenReady {

            shouldStartScanningWhenReady = false
            performScan()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        
        AppLogger.bluetooth.info(
               "didDiscover raw peripheral: \(peripheral.name ?? "Unknown", privacy: .public)"
           )

        let advertisedName =
            advertisementData[
                CBAdvertisementDataLocalNameKey
            ] as? String

        let name =
            advertisedName
            ?? peripheral.name

        guard name ==
                MirabilisDevice.advertisedName else {
            return
        }

        discoveredPeripherals[
            peripheral.identifier
        ] = peripheral

        let device = BluetoothDevice(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue
        )

        AppLogger.bluetooth.debug(
            """
            Discovered \(device.displayName, privacy: .public) \
            [\(device.id.uuidString, privacy: .public)] \
            RSSI \(device.rssi)
            """
        )

        emit(
            .deviceDiscovered(
                device
            )
        )
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        AppLogger.bluetooth.info(
            "Connected to \(peripheral.name ?? "Unknown Device", privacy: .public) [\(peripheral.identifier.uuidString, privacy: .public)]"
        )

        connectedPeripheral = peripheral
        peripheral.delegate = self

        discoveredCharacteristics.removeAll()

        state.activity = .connected(
            peripheral.identifier
        )

        emit(
            .stateChanged(state)
        )

        emit(
            .connected(
                BluetoothDevice(
                    id: peripheral.identifier,
                    name: peripheral.name,
                    rssi: 0
                )
            )
        )

        AppLogger.bluetooth.debug(
            "Discovering services for \(peripheral.identifier.uuidString, privacy: .public)"
        )

        peripheral.discoverServices(
            MirabilisUUID.Service.allCases.map(\.uuid)
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let reason =
            error?.localizedDescription
            ?? "Unknown error"

        AppLogger.bluetooth.error(
            "Connection failed [\(peripheral.identifier.uuidString, privacy: .public)]: \(reason, privacy: .public)"
        )

        state.activity = .idle

        emit(
            .stateChanged(state)
        )

        emit(
            .error(
                .connectionFailed(
                    deviceID: peripheral.identifier,
                    reason: error?.localizedDescription
                )
            )
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if let error {
            AppLogger.bluetooth.error(
                "Disconnected unexpectedly from \(peripheral.name ?? "Unknown Device", privacy: .public) [\(peripheral.identifier.uuidString, privacy: .public)]: \(error.localizedDescription, privacy: .public)"
            )
        } else {
            AppLogger.bluetooth.info(
                "Disconnected from \(peripheral.name ?? "Unknown Device", privacy: .public) [\(peripheral.identifier.uuidString, privacy: .public)]"
            )
        }

        connectedPeripheral = nil
        discoveredCharacteristics.removeAll()

        state.activity = .idle

        emit(
            .stateChanged(state)
        )

        emit(
            .disconnected(
                deviceID: peripheral.identifier
            )
        )

        if let error {
            emit(
                .error(
                    .disconnected(
                        deviceID: peripheral.identifier,
                        reason: error.localizedDescription
                    )
                )
            )
        }
    }
}

private extension BluetoothManager {

    func map(
        _ state: CBManagerState
    ) -> BluetoothState.Availability {
        switch state {

        case .unknown:
            return .unknown

        case .resetting:
            return .resetting

        case .unsupported:
            return .unsupported

        case .unauthorized:
            return .unauthorized

        case .poweredOff:
            return .poweredOff

        case .poweredOn:
            return .poweredOn

        @unknown default:
            return .unknown
        }
    }
}
