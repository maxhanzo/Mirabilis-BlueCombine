//
//  FileTransferView.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 04/09/26.
//

import CoreBluetooth
import SwiftUI
import UniformTypeIdentifiers

struct FileTransferView: View {

    @State var viewModel: FileTransferViewModel

    @State private var isFileImporterPresented = false

    var body: some View {
        List {
            statisticsSection
            transferSection
        }
        .navigationTitle(
            "File Transfer"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .onAppear {
            viewModel.load()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {

            case .success(let urls):
                guard let url = urls.first else {
                    return
                }

                viewModel.selectFile(
                    at: url
                )

            case .failure(let error):
                viewModel.handleFileImporterError(
                    error
                )
            }
        }
        .fileExporter(
            isPresented:
                fileExporterBinding,
            document:
                viewModel.downloadedDocument,
            contentType:
                .data,
            defaultFilename:
                viewModel.defaultDownloadFilename
        ) { result in
            viewModel.handleFileExporterResult(
                result
            )
        }
    }
}

// MARK: - Bindings

private extension FileTransferView {

    var fileExporterBinding:
        Binding<Bool> {
        Binding(
            get: {
                viewModel
                    .isFileExporterPresented
            },
            set: { isPresented in
                viewModel
                    .isFileExporterPresented =
                    isPresented
            }
        )
    }
}

// MARK: - Statistics

private extension FileTransferView {

    var statisticsSection: some View {
        Section(
            "Statistics"
        ) {
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                characteristicHeader(
                    .totalUploadedBytes
                )

                HStack(
                    spacing: 12
                ) {
                    Text(
                        viewModel.totalUploadedBytesText
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    if viewModel
                        .isReadingTotalUploadedBytes {
                        ProgressView()
                            .controlSize(
                                .small
                            )
                    }

                    Button(
                        "Read"
                    ) {
                        viewModel
                            .readTotalUploadedBytes()
                    }
                    .buttonStyle(
                        .bordered
                    )
                    .disabled(
                        viewModel
                            .isReadingTotalUploadedBytes
                    )
                }
            }
            .padding(
                .vertical,
                4
            )
        }
    }
}

// MARK: - Transfer

private extension FileTransferView {

    var transferSection: some View {
        Section(
            "Transfer"
        ) {
            Button {
                isFileImporterPresented = true
            } label: {
                Label(
                    viewModel.hasSelectedFile
                        ? "Choose Another File"
                        : "Choose File",
                    systemImage: "doc.badge.plus"
                )
            }
            .disabled(
                !viewModel.canChooseFile
            )

            if let selectedFile =
                viewModel.selectedFile {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        selectedFile.name
                    )

                    Text(
                        selectedFile.sizeText
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    .vertical,
                    2
                )
            }

            transferProgress

            if viewModel.canCancel {
                Button(
                    role: .destructive
                ) {
                    viewModel.cancelTransfer()
                } label: {
                    Label(
                        "Cancel Transfer",
                        systemImage: "xmark.circle"
                    )
                }
            } else {
                Button {
                    viewModel.uploadSelectedFile()
                } label: {
                    Label(
                        "Upload",
                        systemImage: "arrow.up.circle"
                    )
                }
                .disabled(
                    !viewModel.canUpload
                )

                Button {
                    viewModel.downloadFile()
                } label: {
                    Label(
                        "Download",
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(
                    !viewModel.canDownload
                )
            }

            if let statusText =
                viewModel.transferStatusText {
                Text(
                    statusText
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    transferStatusStyle
                )
            }

            if let errorMessage =
                viewModel.errorMessage {
                Text(
                    errorMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .red
                )
            }
        }
    }

    @ViewBuilder
    var transferProgress: some View {

        if let progress =
            viewModel.uploadProgress {

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                ProgressView(
                    value: progress
                )

                if let progressText =
                    viewModel.uploadProgressText {
                    Text(
                        progressText
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .padding(
                .vertical,
                4
            )

        } else {
            switch viewModel.transferState {

            case .preparingUpload:
                indeterminateProgress(
                    text: "Preparing upload…"
                )

            case .preparingDownload:
                indeterminateProgress(
                    text: "Preparing download…"
                )

            case .downloading(
                let bytesTransferred
            ):
                indeterminateProgress(
                    text:
                        "\(bytesTransferred.formatted()) bytes downloaded"
                )

            default:
                EmptyView()
            }
        }
    }

    func indeterminateProgress(
        text: String
    ) -> some View {
        HStack(
            spacing: 10
        ) {
            ProgressView()
                .controlSize(
                    .small
                )

            Text(
                text
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    var transferStatusStyle: Color {
        switch viewModel.transferState {
        case .failed:
            return .red
        default:
            return .secondary
        }
    }
}

// MARK: - Characteristic Header

private extension FileTransferView {

    func characteristicHeader(
        _ characteristic:
            MirabilisUUID.Characteristic
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 2
        ) {
            Text(
                characteristic.displayName
            )

            Text(
                characteristic.uuid.uuidString
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                .secondary
            )
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
    }
}
