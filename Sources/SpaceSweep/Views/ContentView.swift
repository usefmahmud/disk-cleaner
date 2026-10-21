import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(model.selection?.title ?? "SpaceSweep")
        .frame(minWidth: 900, minHeight: 620)
        .sheet(isPresented: $model.isCleanupSheetPresented) {
            CleanupSheet()
                .environmentObject(model)
        }
        .alert("Couldn't finish that", isPresented: errorBinding) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "An unknown error occurred.")
        }
        .task {
            if !model.hasScanned && !model.isScanning {
                model.scan()
            }
        }
    }

    private var detailContent: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if model.isScanning {
                    ScanningStrip()
                }

                router
            }

            if let toast = model.toast {
                ToastView(message: toast)
                    .padding(.trailing, 24)
                    .padding(.bottom, model.selectedCount > 0 ? 78 : 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.selectedCount > 0 {
                SelectionBar()
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: model.toast)
    }

    @ViewBuilder
    private var router: some View {
        switch model.selection ?? .overview {
        case .overview:
            OverviewView()
        case .quickClean:
            QuickCleanView()
        case let category:
            CategoryDetailView(category: category)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { newValue in
                if !newValue { model.errorMessage = nil }
            }
        )
    }
}
