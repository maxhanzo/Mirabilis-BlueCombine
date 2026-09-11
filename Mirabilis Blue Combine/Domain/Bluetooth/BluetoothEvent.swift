//
//  BluetoothEvent.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Foundation

 enum BluetoothEvent {

    case stateChanged(BluetoothState)

    case deviceDiscovered(BluetoothDevice)

    case connected(BluetoothDevice)

    case disconnected(
        deviceID: UUID
    )

    case servicesDiscovered(
        Set<MirabilisUUID.Service>
    )

    case characteristicsDiscovered(
        Set<MirabilisUUID.Characteristic>
    )

    case valueUpdated(
        characteristic: MirabilisUUID.Characteristic,
        data: Data
    )

    case writeCompleted(
        characteristic: MirabilisUUID.Characteristic
    )

    case notificationStateChanged(
        characteristic: MirabilisUUID.Characteristic,
        isEnabled: Bool
    )

    case error(BluetoothError)
}
