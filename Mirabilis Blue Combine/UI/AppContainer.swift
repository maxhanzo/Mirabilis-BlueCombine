//
//  AppContainer.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Foundation

@MainActor
final class AppContainer {

    let bluetoothManager: BluetoothManaging
    let coordinator: AppCoordinator

    init() {
        let bluetoothManager =
            BluetoothManager()

        self.bluetoothManager =
            bluetoothManager

        self.coordinator =
            AppCoordinator(
                bluetoothManager:
                    bluetoothManager
            )
    }
}
