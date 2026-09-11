//
//  BluetoothDevice.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Foundation

struct BluetoothDevice: Identifiable, Hashable {

    let id: UUID
    let name: String?
    let rssi: Int

    var displayName: String {
        name ?? "Unknown Device"
    }
}
