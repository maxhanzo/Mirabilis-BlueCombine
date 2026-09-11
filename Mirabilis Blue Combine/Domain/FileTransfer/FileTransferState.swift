//
//  FileTransferState.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import Foundation

enum FileTransferCompletion: Equatable {
    case upload(
        bytesTransferred: Int
    )

    case download(
        bytesTransferred: Int
    )
}

enum FileTransferState: Equatable {
    case idle

    case preparingUpload

    case uploading(
        bytesTransferred: Int,
        totalBytes: Int
    )

    case preparingDownload

    case downloading(
        bytesTransferred: Int
    )

    case completed(
        FileTransferCompletion
    )

    case cancelled

    case failed(FileTransferError)

    var isTransferring: Bool {
        switch self {

        case .preparingUpload,
             .uploading,
             .preparingDownload,
             .downloading:
            return true

        case .idle,
             .completed,
             .cancelled,
             .failed:
            return false
        }
    }
}
