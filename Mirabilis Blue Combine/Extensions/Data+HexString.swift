//
//  Data+HexString.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Foundation

extension Data {

    var hexString: String {
        map {
            String(format: "%02X", $0)
        }
        .joined(separator: " ")
    }
}
