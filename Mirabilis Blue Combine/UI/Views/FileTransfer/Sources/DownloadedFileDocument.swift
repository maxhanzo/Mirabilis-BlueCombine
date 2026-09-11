//
//  DownloadedFileDocument.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 04/09/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct DownloadedFileDocument: FileDocument {

    static var readableContentTypes:
        [UTType] {
        [.data]
    }

    let data: Data

    init(
        data: Data
    ) {
        self.data = data
    }

    init(
        configuration:
            ReadConfiguration
    ) throws {
        self.data =
            configuration.file
                .regularFileContents ??
            Data()
    }

    func fileWrapper(
        configuration:
            WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents: data
        )
    }
}
