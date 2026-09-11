//
//  Data+Decoding.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 03/09/26.
//

import Foundation

extension Data {

    var utf8String: String? {
        String(
            data: self,
            encoding: .utf8
        )?
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var uint8Value: UInt8? {
        first
    }

    var uint64LittleEndianValue: UInt64? {
        guard count >= MemoryLayout<UInt64>.size else {
            return nil
        }

        return prefix(MemoryLayout<UInt64>.size)
            .enumerated()
            .reduce(UInt64(0)) { result, element in
                let (offset, byte) = element

                return result |
                    (UInt64(byte) << UInt64(offset * 8))
            }
    }
}
