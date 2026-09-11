//
//  DeviceView.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import CoreBluetooth
import SwiftUI

struct DeviceView: View {

    @State var viewModel: DeviceViewModel
    @State private var isDisconnectAlertPresented = false
    
    let onFileTransferTapped: () -> Void
    let onDisconnectConfirmed: () -> Void

    var body: some View {
        List {
            connectionSection
            deviceInformationSection
            basicOperationsSection
            notificationsSection
            fileTransferSection
        }
        .navigationTitle(
            viewModel.device.displayName
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(
                placement: .topBarLeading
            ) {
                Button {
                    isDisconnectAlertPresented = true
                } label: {
                    Label(
                        "Back",
                        systemImage: "chevron.left"
                    )
                }
            }
        }
        .alert(
            "Disconnect Device?",
            isPresented: $isDisconnectAlertPresented
        ) {
            Button(
                "Cancel",
                role: .cancel
            ) {}

            Button(
                "Disconnect",
                role: .destructive
            ) {
                onDisconnectConfirmed()
            }
        } message: {
            Text(
                "Would you like to disconnect from \(viewModel.device.displayName)?"
            )
        }
    }
}

private extension DeviceView {
    var connectionSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isConnected
                      ? "dot.radiowaves.left.and.right"
                      : "exclamationmark.triangle")
                    .foregroundStyle(viewModel.isConnected ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.device.displayName)
                    Text(viewModel.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    var deviceInformationSection: some View {
        Section("Device Information") {
            ReadCharacteristicRow(
                characteristic: .serialNumber,
                value: viewModel.serialNumber,
                isReading: viewModel.isReading(.serialNumber),
                isEnabled: viewModel.canRead(.serialNumber),
                action: viewModel.readSerialNumber
            )

            ReadCharacteristicRow(
                characteristic: .hardwareRevision,
                value: viewModel.hardwareRevision,
                isReading: viewModel.isReading(.hardwareRevision),
                isEnabled: viewModel.canRead(.hardwareRevision),
                action: viewModel.readHardwareRevision
            )

            ReadCharacteristicRow(
                characteristic: .firmwareRevision,
                value: viewModel.firmwareRevision,
                isReading: viewModel.isReading(.firmwareRevision),
                isEnabled: viewModel.canRead(.firmwareRevision),
                action: viewModel.readFirmwareRevision
            )
        }
    }

    var basicOperationsSection: some View {
        Section("Basic Operations") {
            WriteCharacteristicRow(
                characteristic: .basicWrite,
                text: $viewModel.basicWriteInput,
                buttonTitle: "Write",
                isWriting: viewModel.isWriting(.basicWrite),
                isEnabled: viewModel.canWriteBasicValue,
                action: viewModel.writeBasicValue
            )

            ReadCharacteristicRow(
                characteristic: .lastWrittenValue,
                value: viewModel.lastWrittenValue,
                isReading: viewModel.isReading(.lastWrittenValue),
                isEnabled: viewModel.canRead(.lastWrittenValue),
                action: viewModel.readLastWrittenValue
            )
        }
    }

    var notificationsSection: some View {
        Section("Notifications") {
            WriteCharacteristicRow(
                characteristic: .observableWrite,
                text: $viewModel.observableWriteInput,
                buttonTitle: "Write",
                isWriting: viewModel.isWriting(.observableWrite),
                isEnabled: viewModel.canWriteObservableValue,
                action: viewModel.writeObservableValue
            )

            NotifyCharacteristicRow(
                characteristic: .observableValue,
                value: viewModel.observableValue,
                isNotifying: viewModel.isNotifying(.observableValue),
                isEnabled: viewModel.canNotify(.observableValue)
            ) { enabled in
                viewModel.setNotifications(
                    enabled,
                    for: .observableValue
                )
            }

            NotifyCharacteristicRow(
                characteristic: .periodicEventStream,
                value: viewModel.periodicEventValue,
                isNotifying: viewModel.isNotifying(.periodicEventStream),
                isEnabled: viewModel.canNotify(.periodicEventStream)
            ) { enabled in
                viewModel.setNotifications(
                    enabled,
                    for: .periodicEventStream
                )
            }
        }
    }
}

// MARK: - File Transfer
private extension DeviceView {

    var fileTransferSection: some View {
        Section(
            "File Transfer"
        ) {
            Button {
                onFileTransferTapped()
            } label: {
                HStack(
                    spacing: 12
                ) {
                    Image(
                        systemName:
                            "arrow.up.arrow.down"
                    )

                    Text(
                        "File Transfer"
                    )

                    Spacer()

                    Image(
                        systemName:
                            "chevron.right"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .contentShape(
                    Rectangle()
                )
            }
            .buttonStyle(
                .plain
            )
        }
    }
}

private struct ReadCharacteristicRow: View {
    let characteristic: MirabilisUUID.Characteristic
    let value: String?
    let isReading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CharacteristicHeader(characteristic: characteristic)

            HStack(spacing: 12) {
                Text(value ?? "Not read")
                    .font(.subheadline)
                    .foregroundStyle(value == nil ? .secondary : .primary)
                    .textSelection(.enabled)

                Spacer()

                if isReading {
                    ProgressView().controlSize(.small)
                }

                Button("Read", action: action)
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled || isReading)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WriteCharacteristicRow: View {

    let characteristic: MirabilisUUID.Characteristic
    @Binding var text: String
    let buttonTitle: String
    let isWriting: Bool
    let isEnabled: Bool
    let action: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            CharacteristicHeader(
                characteristic: characteristic
            )

            HStack(
                spacing: 12
            ) {
                TextField(
                    "Value",
                    text: $text
                )
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused(
                    $isTextFieldFocused
                )
                .onSubmit {
                    submit()
                }

                if isWriting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(
                    buttonTitle
                ) {
                    submit()
                }
                .buttonStyle(.bordered)
                .disabled(!isEnabled)
            }
        }
        .padding(
            .vertical,
            4
        )
    }

    private func submit() {
        isTextFieldFocused = false
        action()
    }
}

private struct NotifyCharacteristicRow: View {

    let characteristic: MirabilisUUID.Characteristic
    let value: String?
    let isNotifying: Bool
    let isEnabled: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            CharacteristicHeader(
                characteristic: characteristic
            )

            HStack(
                spacing: 12
            ) {
                Text(
                    value ?? "No value received"
                )
                .font(.subheadline)
                .foregroundStyle(
                    value == nil
                        ? .secondary
                        : .primary
                )
                .textSelection(.enabled)

                Spacer()

                Toggle(
                    "Notify",
                    isOn: Binding(
                        get: {
                            isNotifying
                        },
                        set: { enabled in
                            onChange(enabled)
                        }
                    )
                )
                .labelsHidden()
                .disabled(!isEnabled)
            }
        }
        .padding(
            .vertical,
            4
        )
    }
}

private struct CharacteristicHeader: View {
    let characteristic: MirabilisUUID.Characteristic

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(characteristic.displayName)
            Text(characteristic.uuid.uuidString)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

extension MirabilisUUID.Characteristic {
    var displayName: String {
        switch self {
        case .serialNumber: return "Serial Number"
        case .hardwareRevision: return "Hardware Revision"
        case .firmwareRevision: return "Firmware Revision"
        case .basicWrite: return "Basic Write"
        case .lastWrittenValue: return "Last Written Value"
        case .observableWrite: return "Observable Write"
        case .observableValue: return "Observable Value"
        case .periodicEventStream: return "Periodic Event Stream"
        case .writeWithoutResponse: return "Write Without Response"
        case .lastWriteWithoutResponseValue: return "Last WNR Value"
        case .secureWrite: return "Secure Write"
        case .secureState: return "Secure State"
        case .fileTransferRX: return "File Transfer RX"
        case .fileTransferTX: return "File Transfer TX"
        case .totalUploadedBytes: return "Total Uploaded Bytes"
        }
    }
}
