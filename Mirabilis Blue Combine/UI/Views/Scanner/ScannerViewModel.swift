//
//  ScannerViewModel.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Combine
import Foundation
import OSLog

@MainActor
final class ScannerViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case scanning
        case connecting(BluetoothDevice)
        case noDeviceFound
    }

    // MARK: - Dependencies

    private let bluetoothManager: BluetoothManaging
    private var cancellables = Set<AnyCancellable>()

    var onConnected: ((BluetoothDevice) -> Void)?
    
    // MARK: - State

    @Published
    private(set) var state: State = .idle

    // MARK: - Private

    private var scanTimeoutTask: Task<Void, Never>?

    // MARK: - Init

    init(
        bluetoothManager: BluetoothManaging
    ) {
        self.bluetoothManager = bluetoothManager

        bindBluetoothEvents()
    }
}

// MARK: - Presentation

extension ScannerViewModel {

    var isScanSheetPresented: Bool {
        state != .idle
    }

    var isScanning: Bool {
        state == .scanning
    }

    var canRetry: Bool {
        state == .noDeviceFound
    }
}

// MARK: - User Actions

extension ScannerViewModel {

    func scan() {
        startScan()
    }

    func retry() {
        startScan()
    }

    func cancel() {
        cancelScanTimeout()

        bluetoothManager.stopScanning()

        state = .idle

        AppLogger.ui.debug(
            "BLE scan cancelled by user"
        )
    }
}

// MARK: - Scan Lifecycle

private extension ScannerViewModel {

    func startScan() {
        cancelScanTimeout()

        state = .scanning

        AppLogger.ui.debug(
            "Starting device scan"
        )

        bluetoothManager.startScanning()

        startScanTimeout()
    }

    func startScanTimeout() {
        scanTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    for: .seconds(30)
                )
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            self?.handleScanTimeout()
        }
    }

    func cancelScanTimeout() {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
    }

    func handleScanTimeout() {
        guard state == .scanning else {
            return
        }

        bluetoothManager.stopScanning()

        state = .noDeviceFound

        AppLogger.ui.debug(
            "BLE scan timed out"
        )
    }
}

// MARK: - Lifecycle

extension ScannerViewModel {

    func tearDown() {
        cancelScanTimeout()

        bluetoothManager.stopScanning()

        state = .idle

        AppLogger.ui.debug(
            "ScannerViewModel torn down"
        )
    }
}

// MARK: - Bluetooth Event Bindings

private extension ScannerViewModel {

    func bindBluetoothEvents() {
        bindDeviceDiscovery()
        bindConnection()
        bindErrors()
    }

    func bindDeviceDiscovery() {
        bluetoothManager.events
            .compactMap { event -> BluetoothDevice? in
                guard case .deviceDiscovered(let device) = event else {
                    return nil
                }

                return device
            }
            .sink { [weak self] device in
                self?.handleDiscoveredDevice(
                    device
                )
            }
            .store(in: &cancellables)
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
                self?.handleConnectedDevice(
                    device
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

// MARK: - Bluetooth Event Handling

private extension ScannerViewModel {

    func handleDiscoveredDevice(
        _ device: BluetoothDevice
    ) {
        guard state == .scanning else {
            return
        }

        cancelScanTimeout()

        bluetoothManager.stopScanning()

        state = .connecting(device)

        AppLogger.ui.debug(
            "Device discovered. Connecting to \(device.displayName, privacy: .public)"
        )

        bluetoothManager.connect(
            to: device
        )
    }

    func handleConnectedDevice(
        _ device: BluetoothDevice
    ) {
        guard case .connecting = state else {
            return
        }

        state = .idle

        AppLogger.ui.debug(
            "Device connected. Opening device screen"
        )

        if let onConnected {
            onConnected(device)
        }
    }

    func handleBluetoothError(
        _ error: BluetoothError
    ) {
        switch state {

        case .scanning:
            cancelScanTimeout()
            bluetoothManager.stopScanning()

            state = .noDeviceFound

        case .connecting:
            state = .noDeviceFound

        case .idle,
             .noDeviceFound:
            return
        }

        AppLogger.ui.error(
            "Scanner flow failed: \(error.localizedDescription, privacy: .public)"
        )
    }
}
