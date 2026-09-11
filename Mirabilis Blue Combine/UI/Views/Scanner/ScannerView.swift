//
//  ScannerView.swift
//  Mirabilis Blue
//
//  Created by Max Ueda on 31/08/26.
//

import SwiftUI

struct ScannerView: View {

    @ObservedObject
    var viewModel: ScannerViewModel

    var body: some View {
        VStack {
            Button(
                "Scan"
            ) {
                viewModel.scan()
            }
        }
        .sheet(
            isPresented: scanSheetBinding
        ) {
            ScannerSheet(
                state: viewModel.state,
                retry: viewModel.retry,
                cancel: viewModel.cancel
            )
        }
    }
}

// MARK: - Bindings

private extension ScannerView {

    var scanSheetBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.isScanSheetPresented
            },
            set: { isPresented in
                guard !isPresented else {
                    return
                }

                viewModel.cancel()
            }
        )
    }
}
