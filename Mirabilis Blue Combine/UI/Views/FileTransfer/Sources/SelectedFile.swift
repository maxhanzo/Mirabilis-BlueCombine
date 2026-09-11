//
//  SelectedFile.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 04/09/26.
//

import Foundation

struct SelectedFile: Equatable {

    let name: String
    let data: Data

    var size: Int {
        data.count
    }

    var sizeText: String {
        "\(size.formatted()) bytes"
    }
}
