//
//  AppCoordinatorView.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import SwiftUI

struct AppCoordinatorView: View {
    @ObservedObject
    var coordinator: AppCoordinator

    @ObservedObject
    private var connectionController:
        BluetoothConnectionController

    init(
        coordinator: AppCoordinator
    ) {
        self.coordinator = coordinator
        self.connectionController =
            coordinator.connectionController
    }

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

            if connectionController.isReconnecting {
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
                connectionController
                    .retryConnection()
            }

            Button(
                "Cancel",
                role: .cancel
            ) {
                connectionController
                    .dismissReconnectAlert()
            }
        } message: {
            Text(
                connectionController.reconnectMessage
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
                connectionController
                    .shouldPresentReconnectAlert
            },
            set: { isPresented in
                connectionController
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
