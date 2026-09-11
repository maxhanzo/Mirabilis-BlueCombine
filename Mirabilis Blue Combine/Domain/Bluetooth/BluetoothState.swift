//
//  BluetoothState.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Foundation

struct BluetoothState: Equatable {

    var availability: Availability
    var activity: Activity

    static let initial = BluetoothState(
        availability: .unknown,
        activity: .idle
    )

    enum Availability: Equatable {
        case unknown
        case resetting
        case unsupported
        case unauthorized
        case poweredOff
        case poweredOn
    }

    enum Activity: Equatable {
        case idle
        case scanning
        case connecting(UUID)
        case connected(UUID)
        case disconnecting(UUID)
    }
}
