//
//  FileSelectionError.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 04/09/26.
//

import Foundation

public enum FileSelectionError: LocalizedError {
    case notARegularFile
    case emptyFile
    case fileTooLarge

    public var errorDescription: String? {
        switch self {
        case .notARegularFile:
            return "The selected item is not a file."

        case .emptyFile:
            return "The selected file is empty."

        case .fileTooLarge:
            return """
            The selected file exceeds the \
            \(FileTransferProtocol.maximumFileSize.formatted())-byte limit.
            """
        }
    }
}
