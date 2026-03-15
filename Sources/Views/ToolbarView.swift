import SwiftUI

/// Toolbar controls for the diagram view: zoom, layout, and file actions.
struct ToolbarView: ToolbarContent {
    @EnvironmentObject var appState: AppState

    var body: some ToolbarContent {
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
