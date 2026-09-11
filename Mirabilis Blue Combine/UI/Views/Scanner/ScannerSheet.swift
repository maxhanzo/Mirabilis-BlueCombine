//
//  ScannerSheet.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import SwiftUI

struct ScannerSheet: View {

    let state: ScannerViewModel.State
    let retry: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(
            spacing: 24
        ) {
            Spacer()

            content

            Spacer()
        }
        .padding(24)
        .presentationDetents([
            .height(280)
        ])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(
            isBusy
        )
    }
}

// MARK: - Content

private extension ScannerSheet {

    @ViewBuilder
    var content: some View {
        switch state {

        case .idle:
            EmptyView()

        case .scanning:
            scanningContent

        case .connecting(let device):
            connectingContent(
                device
            )

        case .noDeviceFound:
            noDeviceFoundContent
        }
    }
}

// MARK: - Scanning

private extension ScannerSheet {

    var scanningContent: some View {
        VStack(
            spacing: 16
        ) {
            ProgressView()
                .controlSize(.large)

            Text("Scanning...")
                .font(.headline)

            Button(
                "Cancel",
                action: cancel
            )
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Connecting

private extension ScannerSheet {

    func connectingContent(
        _ device: BluetoothDevice
    ) -> some View {
        VStack(
            spacing: 16
        ) {
            ProgressView()
                .controlSize(.large)

            Text("Connecting...") 
                .font(.headline)

            Text(device.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - No Device Found

private extension ScannerSheet {

    var noDeviceFoundContent: some View {
        VStack(
            spacing: 16
        ) {
            Image(
                systemName: "antenna.radiowaves.left.and.right.slash"
            )
            .font(.system(size: 32))
            .foregroundStyle(.secondary)

            Text(
                "No device has been found"
            )
            .font(.headline)
            .multilineTextAlignment(.center)

            Button(
                "Retry",
                action: retry
            )
            .buttonStyle(.borderedProminent)

            Button(
                "Cancel",
                action: cancel
            )
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Presentation

private extension ScannerSheet {

    var isBusy: Bool {
        switch state {

        case .scanning,
             .connecting:
            return true

        case .idle,
             .noDeviceFound:
            return false
        }
    }
}
