import SwiftUI
import UniformTypeIdentifiers
import SightglassCore

public struct ContentView: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            ZStack {
                if let spec = appState.currentSpec {
                    DiagramView(spec: spec)
                        .overlay(alignment: .topLeading) {
                            if !appState.validationResult.warnings.isEmpty {
                                ValidationStatusBanner(
                                    title: "\(appState.validationResult.warnings.count) warning\(appState.validationResult.warnings.count == 1 ? "" : "s")",
                                    message: "The spec loaded, but some references could not be validated against the current repo.",
                                    isBlocking: false
                                )
                                .padding()
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if appState.selectedNode != nil {
                                DetailPanel()
                                    .frame(width: 340)
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
            allowedContentTypes: supportedSpecTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportedURLs(result)
        }
        .fileImporter(
            isPresented: $appState.showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleImportedURLs(result)
        }
        .fileImporter(
            isPresented: $appState.showSaveLocationPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleSaveLocation(result)
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleDroppedURLs(urls)
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: emptyStateIcon)
                        .font(.system(size: 46))
                        .foregroundStyle(emptyStateAccent)

                    Text(emptyStateTitle)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(emptyStateMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 540)
                }

                HStack(spacing: 12) {
                    Button("Open Folder...") {
                        appState.presentFolderPicker()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open Spec File...") {
                        appState.presentFilePicker()
                    }
                    .buttonStyle(.bordered)
                }

                if let repositoryContext = appState.repositoryContext {
                    WorkspaceSummaryCard(
                        repositoryContext: repositoryContext,
                        specFileURL: appState.specFileURL,
                        freshnessState: appState.freshnessState
                    )
                    .frame(maxWidth: 620)
                }

                if !appState.validationResult.fatalErrors.isEmpty || !appState.validationResult.warnings.isEmpty {
                    ValidationSummaryCard(
                        validationResult: appState.validationResult,
                        isBlocking: !appState.validationResult.fatalErrors.isEmpty
                    )
                    .frame(maxWidth: 620)
                }

                if let errorMessage = appState.errorMessage {
                    ValidationStatusBanner(
                        title: "Open Failed",
                        message: errorMessage,
                        isBlocking: true
                    )
                    .frame(maxWidth: 620)
                }

                if !appState.recentFolders.isEmpty || !appState.recentSpecFiles.isEmpty {
                    RecentLocationsCard(
                        recentFolders: appState.recentFolders,
                        recentSpecFiles: appState.recentSpecFiles
                    ) { location in
                        appState.openRecent(location)
                    }
                    .frame(maxWidth: 620)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateTitle: String {
        if !appState.validationResult.fatalErrors.isEmpty {
            return "Spec Validation Failed"
        }

        if appState.repositoryContext != nil {
            return "Repository Ready"
        }

        return "No Repository Selected"
    }

    private var emptyStateMessage: String {
        if !appState.validationResult.fatalErrors.isEmpty {
            return "This spec cannot render until the blocking validation errors are fixed. Warnings are shown separately so you can see what is safe to ignore."
        }

        if let repositoryContext = appState.repositoryContext {
            if repositoryContext.discoveredSpecURL == nil {
                return "Sightglass can inspect this repository now, even before analysis exists. Open or drop a `.sightglass.yaml` later to render the viewer."
            }
            return "Sightglass found a spec alongside the selected repository and is ready to load it."
        }

        return "Open a folder to inspect repo context, or open and drop a `.sightglass.yaml` file to visualize your code architecture."
    }

    private var emptyStateIcon: String {
        if !appState.validationResult.fatalErrors.isEmpty {
            return "xmark.octagon.fill"
        }

        if appState.repositoryContext != nil {
            return "folder.badge.gearshape"
        }

        return "doc.text.magnifyingglass"
    }

    private var emptyStateAccent: Color {
        appState.validationResult.fatalErrors.isEmpty ? .accentColor : .red
    }

    private var supportedSpecTypes: [UTType] {
        [
            UTType(filenameExtension: "yaml"),
            UTType(filenameExtension: "yml"),
            .plainText,
        ]
        .compactMap { $0 }
    }

    private func handleImportedURLs(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            appState.open(url: url)
        case .failure(let error):
            appState.errorMessage = error.localizedDescription
            appState.freshnessState = .loadFailed
        }
    }

    private func handleDroppedURLs(_ urls: [URL]) -> Bool {
        guard let supportedURL = urls.first(where: { appState.canOpen(url: $0) }) else {
            return false
        }

        appState.open(url: supportedURL)
        return true
    }

    private func handleSaveLocation(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            appState.saveCurrentSpec(in: url)
        case .failure(let error):
            appState.errorMessage = "Failed to choose save location: \(error.localizedDescription)"
        }
    }
}

private struct WorkspaceSummaryCard: View {
    let repositoryContext: AppState.RepositoryContext
    let specFileURL: URL?
    let freshnessState: AppState.FreshnessState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Workspace", systemImage: "folder")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                summaryRow(label: "Repository", value: repositoryContext.displayName)
                summaryRow(label: "Path", value: repositoryContext.rootURL.path)
                summaryRow(label: "Files", value: "\(repositoryContext.sourceFileCount)")

                if let detectedLanguage = repositoryContext.detectedLanguage {
                    summaryRow(label: "Language", value: detectedLanguage)
                }

                if let detectedFramework = repositoryContext.detectedFramework {
                    summaryRow(label: "Framework", value: detectedFramework)
                }

                if let specFileURL {
                    summaryRow(label: "Spec", value: specFileURL.lastPathComponent)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: freshnessState.systemImage)
                Text(freshnessState.title)
                    .fontWeight(.medium)
            }
            .foregroundStyle(freshnessState.isProblem ? .orange : .secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func summaryRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

private struct ValidationSummaryCard: View {
    let validationResult: ValidationResult
    let isBlocking: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ValidationStatusBanner(
                title: isBlocking ? "Blocking validation errors" : "Validation warnings",
                message: isBlocking
                    ? "Sightglass will not render the spec until the fatal issues are fixed."
                    : "These issues do not block rendering, but they should be reviewed.",
                isBlocking: isBlocking
            )

            if !validationResult.fatalErrors.isEmpty {
                issueSection(title: "Blocking Errors", issues: validationResult.fatalErrors, accent: .red)
            }

            if !validationResult.warnings.isEmpty {
                issueSection(title: "Warnings", issues: validationResult.warnings, accent: .orange)
            }

            if !validationResult.remediationHints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hints")
                        .font(.headline)
                    ForEach(validationResult.remediationHints, id: \.self) { hint in
                        Text("• \(hint)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func issueSection(
        title: String,
        issues: [ValidationIssue],
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(issues) { issue in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                        Text(issue.message)
                            .fontWeight(.medium)
                    }

                    if let path = issue.path {
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ValidationStatusBanner: View {
    let title: String
    let message: String
    let isBlocking: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: isBlocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isBlocking ? Color.red.opacity(0.12) : Color.orange.opacity(0.14)),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isBlocking ? Color.red.opacity(0.35) : Color.orange.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct RecentLocationsCard: View {
    let recentFolders: [AppState.RecentLocation]
    let recentSpecFiles: [AppState.RecentLocation]
    let openLocation: (AppState.RecentLocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Recent Workspaces", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            if !recentFolders.isEmpty {
                locationSection(title: "Folders", locations: recentFolders)
            }

            if !recentSpecFiles.isEmpty {
                locationSection(title: "Spec Files", locations: recentSpecFiles)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func locationSection(
        title: String,
        locations: [AppState.RecentLocation]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(locations) { location in
                Button {
                    openLocation(location)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.displayName)
                            .fontWeight(.medium)
                        Text(location.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
