import SwiftUI

/// Toolbar controls for the diagram view: zoom, layout, and file actions.
struct ToolbarView: ToolbarContent {
    @EnvironmentObject var appState: AppState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                appState.presentFolderPicker()
            } label: {
                Label("Open Folder", systemImage: "folder")
            }
            .help("Open Folder")

            Button {
                appState.presentFilePicker()
            } label: {
                Label("Open Spec", systemImage: "doc")
            }
            .help("Open Spec File")
        }

        ToolbarItem(placement: .automatic) {
            Label(appState.freshnessState.title, systemImage: appState.freshnessState.systemImage)
                .font(.caption)
                .foregroundStyle(appState.freshnessState.isProblem ? .orange : .secondary)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            // Zoom controls
            Button {
                withAnimation {
                    appState.zoomLevel = max(0.1, appState.zoomLevel - 0.2)
                }
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")

            Text("\(Int(appState.zoomLevel * 100))%")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 40)

            Button {
                withAnimation {
                    appState.zoomLevel = min(5.0, appState.zoomLevel + 0.2)
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")

            Divider()

            // Reset view
            Button {
                withAnimation {
                    appState.resetView()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Reset View")

            // Re-layout
            Button {
                if let spec = appState.currentSpec {
                    withAnimation {
                        appState.computeLayout(for: spec)
                    }
                }
            } label: {
                Image(systemName: "arrow.triangle.branch")
            }
            .help("Recompute Layout")
            .disabled(appState.currentSpec == nil)
        }
    }
}
