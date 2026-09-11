//
//  DeviceViewModel.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Combine
import CoreBluetooth
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class DeviceViewModel {

    // MARK: - State

    enum State: Equatable {
        case loading
        case ready
        case disconnected
        case failed(String)
    }

    // MARK: - Dependencies

    private let bluetoothManager: BluetoothManaging

    @ObservationIgnored
    private var cancellables =
        Set<AnyCancellable>()

    // MARK: - Device

    let device: BluetoothDevice

    // MARK: - Presentation State

    private(set) var state: State = .loading

    private(set) var serialNumber: String?
    private(set) var hardwareRevision: String?
    private(set) var firmwareRevision: String?
    private(set) var lastWrittenValue: String?
    
    private(set) var observableValue: String?
    private(set) var periodicEventValue: String?

    private(set) var notifyingCharacteristics:
        Set<MirabilisUUID.Characteristic> = []

    var observableWriteInput = ""

    private(set) var characteristics:
        Set<MirabilisUUID.Characteristic> = []

    private(set) var readingCharacteristics:
        Set<MirabilisUUID.Characteristic> = []

    private(set) var writingCharacteristics:
        Set<MirabilisUUID.Characteristic> = []

    var basicWriteInput = ""
    
    @ObservationIgnored
    var onDisconnected: (() -> Void)?

    // MARK: - Init

    init(
        device: BluetoothDevice,
        bluetoothManager: BluetoothManaging
    ) {
        self.device = device
        self.bluetoothManager = bluetoothManager

        bindBluetoothEvents()

        AppLogger.ui.debug(
            "DeviceViewModel initialized for \(device.displayName, privacy: .public)"
        )
    }
}

// MARK: - Presentation

extension DeviceViewModel {

    var deviceInformationCharacteristics: [
        MirabilisUUID.Characteristic
    ] {
        characteristics.filter {
            $0.service == .deviceInformation
        }
    }

    var isLoading: Bool {
        state == .loading
    }

    var isConnected: Bool {
        switch state {
        case .loading,
             .ready:
            return true

        case .disconnected,
             .failed:
            return false
        }
    }

    var statusText: String {
        switch state {
        case .loading:
            return "Discovering characteristics…"

        case .ready:
            return "Connected"

        case .disconnected:
            return "Disconnected"

        case .failed(let message):
            return message
        }
    }

    func value(
        for characteristic: MirabilisUUID.Characteristic
    ) -> String? {
        switch characteristic {
        case .serialNumber:
            return serialNumber

        case .hardwareRevision:
            return hardwareRevision

        case .firmwareRevision:
            return firmwareRevision

        case .lastWrittenValue:
            return lastWrittenValue

        case .observableValue:
            return observableValue

        case .periodicEventStream:
            return periodicEventValue

        default:
            return nil
        }
    }

    func canRead(
        _ characteristic: MirabilisUUID.Characteristic
    ) -> Bool {
        guard state == .ready else {
            return false
        }

        return characteristics.contains(
            characteristic
        )
    }

    func isReading(
        _ characteristic: MirabilisUUID.Characteristic
    ) -> Bool {
        readingCharacteristics.contains(
            characteristic
        )
    }

    func isWriting(
        _ characteristic: MirabilisUUID.Characteristic
    ) -> Bool {
        writingCharacteristics.contains(
            characteristic
        )
    }

    var canWriteBasicValue: Bool {
        state == .ready &&
        characteristics.contains(.basicWrite) &&
        !basicWriteInput.isEmpty &&
        !isWriting(.basicWrite)
    }

    var canWriteObservableValue: Bool {
        state == .ready &&
        characteristics.contains(.observableWrite) &&
        !observableWriteInput.isEmpty &&
        !isWriting(.observableWrite)
    }

    func canNotify(
        _ characteristic: MirabilisUUID.Characteristic
    ) -> Bool {
        state == .ready &&
        characteristics.contains(characteristic) &&
        characteristic.supportsNotifications
    }

    func isNotifying(
        _ characteristic: MirabilisUUID.Characteristic
    ) -> Bool {
        notifyingCharacteristics.contains(
            characteristic
        )
    }
}

// MARK: - User Actions

extension DeviceViewModel {

    func readSerialNumber() {
        read(
            .serialNumber
        )
    }

    func readHardwareRevision() {
        read(
            .hardwareRevision
        )
    }

    func readFirmwareRevision() {
        read(
            .firmwareRevision
        )
    }

    func readLastWrittenValue() {
        read(
            .lastWrittenValue
        )
    }

    func writeBasicValue() {
        guard canWriteBasicValue,
              let data = basicWriteInput.data(using: .utf8) else {
            return
        }

        writingCharacteristics.insert(.basicWrite)

        bluetoothManager.write(
            data,
            to: .basicWrite
        )
    }

    func read(
        _ characteristic: MirabilisUUID.Characteristic
    ) {
        guard canRead(characteristic) else {
            return
        }

        readingCharacteristics.insert(
            characteristic
        )

        AppLogger.ui.debug(
            "Reading characteristic \(characteristic.uuid.uuidString, privacy: .public)"
        )

        bluetoothManager.read(
            characteristic
        )
    }
    
    func writeObservableValue() {
        guard canWriteObservableValue,
              let data = observableWriteInput.data(using: .utf8) else {
            return
        }

        writingCharacteristics.insert(
            .observableWrite
        )

        bluetoothManager.write(
            data,
            to: .observableWrite
        )
    }

    func toggleObservableValueNotifications() {
        toggleNotifications(
            for: .observableValue
        )
    }

    func togglePeriodicEventNotifications() {
        toggleNotifications(
            for: .periodicEventStream
        )
    }

    func setNotifications(
        _ enabled: Bool,
        for characteristic: MirabilisUUID.Characteristic
    ) {
        guard canNotify(characteristic) else {
            return
        }

        bluetoothManager.setNotifications(
            enabled,
            for: characteristic
        )
    }
    

    func disconnect() {
        bluetoothManager.disconnect()
    }

    private func toggleNotifications(
        for characteristic: MirabilisUUID.Characteristic
    ) {
        setNotifications(
            !isNotifying(characteristic),
            for: characteristic
        )
    }
}

// MARK: - Lifecycle

extension DeviceViewModel {

    func tearDown() {
        AppLogger.ui.debug(
            "DeviceViewModel torn down"
        )
    }
}

// MARK: - Bluetooth Event Bindings

private extension DeviceViewModel {

    func bindBluetoothEvents() {
        bindCharacteristicDiscovery()
        bindValueUpdates()
        bindWriteCompletions()
        bindNotificationStateChanges()
        bindDisconnections()
        bindErrors()
    }

    func bindCharacteristicDiscovery() {
        bluetoothManager.events
            .compactMap { event -> Set<MirabilisUUID.Characteristic>? in
                guard case .characteristicsDiscovered(let characteristics) = event else {
                    return nil
                }

                return characteristics
            }
            .sink { [weak self] characteristics in
                self?.handleDiscoveredCharacteristics(
                    characteristics
                )
            }
            .store(in: &cancellables)
    }

    func bindValueUpdates() {
        bluetoothManager.events
            .compactMap { event -> (MirabilisUUID.Characteristic, Data)? in
                guard case .valueUpdated(
                    characteristic: let characteristic,
                    data: let data
                ) = event else {
                    return nil
                }

                return (characteristic, data)
            }
            .sink { [weak self] characteristic, data in
                self?.handleUpdatedValue(
                    data,
                    for: characteristic
                )
            }
            .store(in: &cancellables)
    }

    func bindWriteCompletions() {
        bluetoothManager.events
            .compactMap { event -> MirabilisUUID.Characteristic? in
                guard case .writeCompleted(let characteristic) = event else {
                    return nil
                }

                return characteristic
            }
            .sink { [weak self] characteristic in
                self?.writingCharacteristics.remove(
                    characteristic
                )
            }
            .store(in: &cancellables)
    }

    func bindNotificationStateChanges() {
        bluetoothManager.events
            .compactMap {
                event -> (MirabilisUUID.Characteristic, Bool)? in

                guard case .notificationStateChanged(
                    characteristic: let characteristic,
                    isEnabled: let isEnabled
                ) = event else {
                    return nil
                }

                return (characteristic, isEnabled)
            }
            .sink { [weak self] characteristic, isEnabled in
                self?.handleNotificationStateChanged(
                    characteristic,
                    isEnabled: isEnabled
                )
            }
            .store(in: &cancellables)
    }

    func bindDisconnections() {
        bluetoothManager.events
            .compactMap { event -> UUID? in
                guard case .disconnected(let deviceID) = event else {
                    return nil
                }

                return deviceID
            }
            .sink { [weak self] deviceID in
                self?.handleDisconnectedDevice(
                    deviceID
                )
            }
            .store(in: &cancellables)
    }

    func bindErrors() {
        bluetoothManager.events
            .compactMap { event -> BluetoothError? in
                guard case .error(let error) = event else {
                    return nil
                }

                return error
            }
            .sink { [weak self] error in
                self?.handleBluetoothError(
                    error
                )
            }
            .store(in: &cancellables)
    }
}

// MARK: - Characteristic Discovery

private extension DeviceViewModel {

    func handleDiscoveredCharacteristics(
        _ discoveredCharacteristics:
            Set<MirabilisUUID.Characteristic>
    ) {
        characteristics.formUnion(
            discoveredCharacteristics
        )

        state = .ready

        AppLogger.ui.debug(
            "Device characteristics available: \(self.characteristics.count)"
        )
    }
}

// MARK: - Value Updates

private extension DeviceViewModel {

    func handleUpdatedValue(
        _ data: Data,
        for characteristic:
            MirabilisUUID.Characteristic
    ) {
        readingCharacteristics.remove(
            characteristic
        )

        switch characteristic {

        case .serialNumber:
            serialNumber = data.utf8String

        case .hardwareRevision:
            hardwareRevision = data.utf8String

        case .firmwareRevision:
            firmwareRevision = data.utf8String

        case .lastWrittenValue:
            lastWrittenValue = data.utf8String

        case .observableValue:
            observableValue = data.utf8String

        case .periodicEventStream:
            periodicEventValue = data.uint8Value.map(String.init)

        default:
            break
        }
    }

    func handleNotificationStateChanged(
        _ characteristic: MirabilisUUID.Characteristic,
        isEnabled: Bool
    ) {
        if isEnabled {
            notifyingCharacteristics.insert(
                characteristic
            )
        } else {
            notifyingCharacteristics.remove(
                characteristic
            )
        }
    }
}

// MARK: - Connection Handling

private extension DeviceViewModel {

    func handleDisconnectedDevice(
        _ deviceID: UUID
    ) {
        guard deviceID == device.id else {
            return
        }

        readingCharacteristics.removeAll()
        writingCharacteristics.removeAll()
        notifyingCharacteristics.removeAll()

        state = .disconnected

        AppLogger.ui.info(
            "Device disconnected while DeviceView is active"
        )

        onDisconnected?()
    }

    func handleBluetoothError(
        _ error: BluetoothError
    ) {
        readingCharacteristics.removeAll()
        writingCharacteristics.removeAll()
        notifyingCharacteristics.removeAll()

        AppLogger.ui.error(
            "Device flow error: \(error.localizedDescription, privacy: .public)"
        )

        state = .failed(
            error.localizedDescription
        )
    }
}
