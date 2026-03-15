import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            ZStack {
                if let spec = appState.currentSpec {
                    DiagramView(spec: spec)
                        .overlay(alignment: .topTrailing) {
                            if appState.selectedNode != nil {
                                DetailPanel()
                                    .frame(width: 300)
                                    .padding()
                            }
                        }
                } else {
                    emptyState
                }
            }
        }
        .toolbar {
            ToolbarView()
        }
        .fileImporter(
            isPresented: $appState.showFilePicker,
            allowedContentTypes: [.yaml, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Spec Loaded")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open a YAML spec file or drop one here to visualize your code architecture.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Button("Open Spec File...") {
                appState.showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            appState.loadSpec(from: url)
        case .failure(let error):
            appState.errorMessage = error.localizedDescription
        }
    }
}
