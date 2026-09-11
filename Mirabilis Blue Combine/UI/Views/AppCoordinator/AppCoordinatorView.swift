//
//  AppCoordinatorView.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import SwiftUI

struct AppCoordinatorView: View {
    @Bindable var coordinator:
        AppCoordinator

    var body: some View {
        ZStack {
            NavigationStack(
                path: $coordinator.path
            ) {
                ScannerView(
                    viewModel:
                        coordinator
                            .scannerViewModel
                )
                .navigationDestination(
                    for:
                        AppCoordinator.Route.self
                ) { route in
                    destination(
                        for: route
                    )
                }
            }

            if coordinator.isReconnecting {
                reconnectingOverlay
                    .zIndex(1)
            }
        }
        .alert(
            "Bluetooth Disconnected",
            isPresented:
                reconnectAlertBinding
        ) {
            Button(
                "Reconnect"
            ) {
                coordinator
                    .retryBluetoothConnection()
            }

            Button(
                "Cancel",
                role: .cancel
            ) {
                coordinator
                    .dismissReconnectAlert()
            }
        } message: {
            Text(
                coordinator.reconnectMessage
            )
        }
    }
}

// MARK: - Bindings

private extension AppCoordinatorView {
    var reconnectAlertBinding:
        Binding<Bool> {
        Binding(
            get: {
                coordinator
                    .shouldPresentReconnectAlert
            },
            set: { isPresented in
                coordinator
                    .shouldPresentReconnectAlert =
                    isPresented
            }
        )
    }
}

// MARK: - Destinations

private extension AppCoordinatorView {
    @ViewBuilder
    func destination(
        for route:
            AppCoordinator.Route
    ) -> some View {
        switch route {

        case .device(let device):
            DeviceView(
                viewModel:
                    coordinator
                        .makeDeviceViewModel(
                            device: device
                        ),
                onFileTransferTapped: {
                    coordinator
                        .showFileTransfer(
                            for: device
                        )
                },
                onDisconnectConfirmed: {
                    coordinator
                        .disconnectAndReturnToScanner()
                }
            )

        case .fileTransfer(let device):
            FileTransferView(
                viewModel:
                    coordinator
                        .makeFileTransferViewModel(
                            device: device
                        )
            )
        }
    }
}

// MARK: - Overlay

private extension AppCoordinatorView {
    var reconnectingOverlay: some View {
        ZStack {
            Color.black
                .opacity(0.25)
                .ignoresSafeArea()

            VStack(
                spacing: 16
            ) {
                ProgressView()
                    .controlSize(.large)

                Text("Reconnecting...")
                    .font(.headline)
            }
            .padding(28)
            .background(
                .regularMaterial,
                in: RoundedRectangle(
                    cornerRadius: 16
                )
            )
        }
        .transition(
            .opacity
        )
    }
}
