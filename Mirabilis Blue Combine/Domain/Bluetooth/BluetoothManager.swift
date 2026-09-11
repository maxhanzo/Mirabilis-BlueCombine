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

    private var observers: [
        WeakBluetoothObserver
    ] = []

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

// MARK: - Weak Observer

private final class WeakBluetoothObserver {

    weak var value: BluetoothObserving?

    init(_ value: BluetoothObserving) {
        self.value = value
    }
}

// MARK: - Observer Management

extension BluetoothManager {

    func addObserver(
        _ observer: BluetoothObserving
    ) {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.removeReleasedObservers()

            let alreadyExists = self.observers.contains {
                guard let value = $0.value else {
                    return false
                }

                return ObjectIdentifier(value)
                    == ObjectIdentifier(observer)
            }

            guard !alreadyExists else {
                return
            }

            self.observers.append(
                WeakBluetoothObserver(observer)
            )
        }
    }

    func removeObserver(
        _ observer: BluetoothObserving
    ) {
        let observerID =
            ObjectIdentifier(observer)

        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.observers.removeAll {
                guard let value = $0.value else {
                    return true
                }

                return ObjectIdentifier(value)
                    == observerID
            }
        }
    }

    private func removeReleasedObservers() {
        observers.removeAll {
            $0.value == nil
        }
    }
}

// MARK: - Event Delivery

extension BluetoothManager {

    func emit(_ event: BluetoothEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // New Combine path
            eventSubject.send(event)

            // Existing observer path — temporary
            observers.forEach {
                $0.value?.bluetoothManager(
                    self,
                    didReceive: event
                )
            }
        }
    }
}
