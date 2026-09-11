//
//  BluetoothManager.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Combine
import CoreBluetooth
import Foundation
import OSLog

final class BluetoothManager: NSObject, BluetoothManaging {

    private let eventSubject =
          PassthroughSubject<BluetoothEvent, Never>()

    var events: AnyPublisher<BluetoothEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
          
    let bluetoothQueue = DispatchQueue(
        label: "com.mirabilis.bluetooth",
        qos: .userInitiated
    )

    lazy var centralManager: CBCentralManager = {
        AppLogger.bluetooth.debug(
            "Initializing CBCentralManager"
        )

        return CBCentralManager(
            delegate: self,
            queue: bluetoothQueue
        )
    }()

    var state: BluetoothState = .initial
    
    var shouldStartScanningWhenReady = false

    var discoveredPeripherals: [
        UUID: CBPeripheral
    ] = [:]

    var connectedPeripheral: CBPeripheral?

    var discoveredCharacteristics: [
        MirabilisUUID.Characteristic: CBCharacteristic
    ] = [:]


    override init() {
        super.init()

        AppLogger.bluetooth.debug(
            "BluetoothManager initialized"
        )
    }

    deinit {
        AppLogger.bluetooth.debug(
            "BluetoothManager deinitialized"
        )
    }
}

// MARK: - Event Delivery

extension BluetoothManager {

    func emit(_ event: BluetoothEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSubject.send(event)
        }
    }
}
