//
//  BluetoothManager.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Combine
import Foundation

protocol BluetoothManaging:
    BluetoothScanning,
    BluetoothConnecting,
    BluetoothGATTAccessing,
    BluetoothEventProviding {
}

protocol BluetoothScanning: AnyObject {

    func startScanning()
    func stopScanning()
}

protocol BluetoothConnecting: AnyObject {

    func connect(to device: BluetoothDevice)
    func disconnect()
}

protocol BluetoothGATTAccessing: AnyObject {

    func read(
        _ characteristic: MirabilisUUID.Characteristic
    )

    func write(
        _ data: Data,
        to characteristic: MirabilisUUID.Characteristic
    )

    func setNotifications(
        _ enabled: Bool,
        for characteristic: MirabilisUUID.Characteristic
    )
}

protocol BluetoothEventProviding: AnyObject {

    var events: AnyPublisher<BluetoothEvent, Never> { get }
}
