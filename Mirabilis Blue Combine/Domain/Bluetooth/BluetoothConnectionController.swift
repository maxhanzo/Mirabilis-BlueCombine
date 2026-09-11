//
//  BluetoothConnectionController.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 04/09/26.
//

import Combine
import CoreBluetooth
import Foundation
import OSLog

@MainActor
final class BluetoothConnectionController: ObservableObject {

    enum State: Equatable {
        case disconnected
        case connecting
        case connected(BluetoothDevice)
    }

    private let bluetoothManager:
        BluetoothManaging

    private var cancellables =
        Set<AnyCancellable>()

    @Published
    private(set) var state:
        State = .disconnected

    @Published
    private(set) var lastConnectedDevice:
        BluetoothDevice?

    @Published
    private(set) var isReconnecting = false
    
    @Published
    var shouldPresentReconnectAlert = false

    private var intentionalDisconnectDeviceID:
        UUID?

    init(
        bluetoothManager: BluetoothManaging
    ) {
        self.bluetoothManager = bluetoothManager

        bindBluetoothEvents()

        AppLogger.bluetooth.debug(
            "BluetoothConnectionController initialized"
        )
    }
}

// MARK: - Presentation

extension BluetoothConnectionController {

    var isConnected: Bool {
        if case .connected = state {
            return true
        }

        return false
    }

    var isConnecting: Bool {
        state == .connecting
    }

    var reconnectMessage: String {
        guard let device =
                lastConnectedDevice else {
            return """
            The Bluetooth connection was lost.
            """
        }

        return """
        The connection to \
        \(device.displayName) was lost. \
        Move closer to the device and try again.
        """
    }
}

// MARK: - Actions

extension BluetoothConnectionController {

    func retryConnection() {
        guard let device =
                lastConnectedDevice else {
            shouldPresentReconnectAlert = false
            return
        }

        guard !isReconnecting else {
            return
        }

        shouldPresentReconnectAlert = false
        isReconnecting = true
        state = .connecting

        AppLogger.bluetooth.info(
            "Retrying connection to \(device.displayName, privacy: .public)"
        )

        bluetoothManager.connect(
            to: device
        )
    }

    func dismissReconnectAlert() {
        shouldPresentReconnectAlert = false
    }
}

// MARK: - Bluetooth Event Bindings

private extension BluetoothConnectionController {

    func bindBluetoothEvents() {
        bindConnection()
        bindDisconnection()
        bindBluetoothState()
        bindErrors()
    }

    func bindConnection() {
        bluetoothManager.events
            .compactMap { event -> BluetoothDevice? in
                guard case .connected(let device) = event else {
                    return nil
                }

                return device
            }
            .sink { [weak self] device in
                self?.handleConnected(
                    device
                )
            }
            .store(in: &cancellables)
    }

    func bindDisconnection() {
        bluetoothManager.events
            .compactMap { event -> UUID? in
                guard case .disconnected(let deviceID) = event else {
                    return nil
                }

                return deviceID
            }
            .sink { [weak self] deviceID in
                self?.handleDisconnected(
                    deviceID
                )
            }
            .store(in: &cancellables)
    }

    func bindBluetoothState() {
        bluetoothManager.events
            .compactMap { event -> BluetoothState? in
                guard case .stateChanged(let bluetoothState) = event else {
                    return nil
                }

                return bluetoothState
            }
            .sink { [weak self] bluetoothState in
                self?.handleBluetoothStateChanged(
                    bluetoothState
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

// MARK: - Event Handling

private extension BluetoothConnectionController {

    func handleConnected(
        _ device: BluetoothDevice
    ) {
        lastConnectedDevice = device
        intentionalDisconnectDeviceID = nil
        shouldPresentReconnectAlert = false
        isReconnecting = false
        state = .connected(device)
    }

    func handleDisconnected(
        _ deviceID: UUID
    ) {
        let wasIntentional =
            intentionalDisconnectDeviceID ==
            deviceID

        intentionalDisconnectDeviceID = nil
        state = .disconnected

        guard !wasIntentional,
              lastConnectedDevice?.id ==
                deviceID else {
            shouldPresentReconnectAlert = false
            return
        }

        shouldPresentReconnectAlert = true

        AppLogger.bluetooth.info(
            "Connection controller: unexpected disconnect"
        )
    }

    func handleBluetoothStateChanged(
        _ bluetoothState: BluetoothState
    ) {
        switch bluetoothState.activity {

        case .disconnecting(let deviceID):
            intentionalDisconnectDeviceID =
                deviceID

        case .connecting:
            state = .connecting

        case .connected:
            break

        case .idle,
             .scanning:
            break
        }
    }

    func handleBluetoothError(
        _ error: BluetoothError
    ) {
        guard isReconnecting else {
            return
        }

        switch error {

        case .connectionFailed,
             .deviceNotFound,
             .bluetoothUnavailable:

            isReconnecting = false
            state = .disconnected

            shouldPresentReconnectAlert =
                lastConnectedDevice != nil

        default:
            break
        }
    }
}
