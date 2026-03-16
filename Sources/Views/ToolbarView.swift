import SwiftUI

/// Toolbar controls for the diagram view: zoom, layout, file actions, and export.
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
            .keyboardShortcut("o")

            Button {
                appState.presentFilePicker()
            } label: {
                Label("Open Spec", systemImage: "doc")
            }
            .help("Open Spec File")

            Button {
                appState.saveCurrentSpec()
            } label: {
                Label("Save Spec", systemImage: "square.and.arrow.down")
            }
            .help(appState.specFileURL == nil ? "Save Spec As .sightglass.yaml" : "Save Spec")
            .disabled(!appState.canSave)
            .keyboardShortcut("s")
        }

        ToolbarItem(placement: .automatic) {
            Label(appState.freshnessState.title, systemImage: appState.freshnessState.systemImage)
                .font(.caption)
                .foregroundStyle(appState.freshnessState.isProblem ? .orange : .secondary)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            // Layout algorithm picker
            Picker("Layout", selection: layoutAlgorithmBinding) {
                ForEach(AppState.LayoutAlgorithm.allCases, id: \.self) { algorithm in
                    Text(algorithm.displayName).tag(algorithm)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .help("Layout Algorithm")

            Divider()

            // Zoom controls
            Button {
                withAnimation {
                    appState.zoomLevel = max(0.1, appState.zoomLevel - 0.2)
                }
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")
            .keyboardShortcut("-")

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
            .keyboardShortcut("=")

            Divider()

            // Fit to screen
            Button {
                withAnimation {
                    appState.fitToScreen()
                }
            } label: {
                Image(systemName: "aspectratio")
            }
            .help("Fit to Screen")
            .keyboardShortcut("0")

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

            Divider()

            // Export
            Button {
                appState.requestExport()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Export Diagram")
            .keyboardShortcut("e")
            .disabled(appState.currentSpec == nil)
        }
    }

    private var layoutAlgorithmBinding: Binding<AppState.LayoutAlgorithm> {
        Binding(
            get: { appState.layoutAlgorithm },
            set: { newValue in
                appState.layoutAlgorithm = newValue
                if let spec = appState.currentSpec {
                    withAnimation {
                        appState.computeLayout(for: spec)
                    }
                }
            }
        )
    }
}
