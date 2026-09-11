//
//  AppLogger.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import OSLog

nonisolated enum AppLogger {

    private static let subsystem = "MirabilisBlue"

    static let bluetooth = Logger(
        subsystem: subsystem,
        category: "Bluetooth"
    )

    static let fileTransfer = Logger(
        subsystem: subsystem,
        category: "FileTransfer"
    )

    static let navigation = Logger(
        subsystem: subsystem,
        category: "Navigation"
    )

    static let ui = Logger(
        subsystem: subsystem,
        category: "UI"
    )
}
