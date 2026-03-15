import SwiftUI
import SightglassCore

/// Sidebar showing the loaded spec's nodes organized by layer,
/// along with file loading controls.
struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            workspaceSection
            validationSection

            if let spec = appState.currentSpec {
                specInfoSection(spec)
                layersSection(spec)
                entryPointsSection(spec)
            }

            recentLocationsSection
            noSpecSection
        }
        .listStyle(.sidebar)
        .navigationTitle("Sightglass")
    }

    // MARK: - Sections

    private var workspaceSection: some View {
        Group {
            if let repositoryContext = appState.repositoryContext {
                Section("Workspace") {
                    LabeledContent("Repository", value: repositoryContext.displayName)
                    LabeledContent("Files", value: "\(repositoryContext.sourceFileCount)")

                    if let detectedLanguage = repositoryContext.detectedLanguage {
                        LabeledContent("Language", value: detectedLanguage)
                    }

                    if let detectedFramework = repositoryContext.detectedFramework {
                        LabeledContent("Framework", value: detectedFramework)
                    }

                    if let specFileURL = appState.specFileURL {
                        LabeledContent("Spec", value: specFileURL.lastPathComponent)
                    }

                    Label(appState.freshnessState.title, systemImage: appState.freshnessState.systemImage)
                        .foregroundStyle(appState.freshnessState.isProblem ? .orange : .secondary)
                }
            }
        }
    }

    private func specInfoSection(_ spec: CodeSpec) -> some View {
        Section("Project") {
            LabeledContent("Name", value: spec.name)
            LabeledContent("Version", value: "\(spec.version)")
            LabeledContent("Nodes", value: "\(spec.nodes.count)")
            LabeledContent("Edges", value: "\(spec.edges.count)")
        }
    }

    private func layersSection(_ spec: CodeSpec) -> some View {
        let layers = spec.layers.filter { appState.visibleLayerIDs.contains($0.id) || appState.visibleLayerIDs.isEmpty }

        return ForEach(layers) { layer in
            Section(layer.name) {
                let layerNodes = spec.nodes.filter { node in
                    node.layer == layer.id && matchesSearch(node)
                }
                ForEach(layerNodes) { node in
                    nodeRow(node, layerColor: layer.swiftUIColor)
                }
            }
        }
    }

    private func entryPointsSection(_ spec: CodeSpec) -> some View {
        Group {
            if let entryPoints = spec.entryPoints, !entryPoints.isEmpty {
                Section("Entry Points") {
                    ForEach(entryPoints) { ep in
                        Button {
                            appState.activateEntryPoint(id: ep.id)
                        } label: {
                            HStack {
                            Image(systemName: iconForEntryPointType(ep.type))
                                .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                if let method = ep.method, let path = ep.path {
                                    Text("\(method) \(path)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                } else if let path = ep.path {
                                    Text(path)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                Text(ep.type.uppercased())
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var validationSection: some View {
        Group {
            if !appState.validationResult.fatalErrors.isEmpty || !appState.validationResult.warnings.isEmpty {
                Section("Validation") {
                    if !appState.validationResult.fatalErrors.isEmpty {
                        Label(
                            "\(appState.validationResult.fatalErrors.count) blocking error\(appState.validationResult.fatalErrors.count == 1 ? "" : "s")",
                            systemImage: "xmark.octagon.fill"
                        )
                        .foregroundStyle(.red)

                        ForEach(appState.validationResult.fatalErrors.prefix(5)) { issue in
                            validationIssueRow(issue)
                        }
                    }

                    if !appState.validationResult.warnings.isEmpty {
                        Label(
                            "\(appState.validationResult.warnings.count) warning\(appState.validationResult.warnings.count == 1 ? "" : "s")",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)

                        ForEach(appState.validationResult.warnings.prefix(5)) { issue in
                            validationIssueRow(issue)
                        }
                    }
                }
            }
        }
    }

    private var recentLocationsSection: some View {
        Group {
            if !appState.recentFolders.isEmpty {
                Section("Recent Folders") {
                    ForEach(appState.recentFolders.prefix(5)) { location in
                        recentLocationRow(location)
                    }
                }
            }

            if !appState.recentSpecFiles.isEmpty {
                Section("Recent Spec Files") {
                    ForEach(appState.recentSpecFiles.prefix(5)) { location in
                        recentLocationRow(location)
                    }
                }
            }
        }
    }

    private var noSpecSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: appState.repositoryContext == nil ? "doc.text.magnifyingglass" : "folder.badge.gearshape")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text(appState.currentSpec == nil ? "Open a folder or spec" : "Workspace actions")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Button("Open Folder...") {
                    appState.presentFolderPicker()
                }
                .buttonStyle(.borderedProminent)

                Button("Open Spec File...") {
                    appState.presentFilePicker()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    // MARK: - Node Row

    private func nodeRow(_ node: SpecNode, layerColor: Color) -> some View {
        Button {
            appState.selectNode(id: node.id)
        } label: {
            HStack {
                Circle()
                    .fill(layerColor)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading) {
                    Text(node.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    if let file = node.file {
                        Text(file)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(
            appState.selectedNodeID == node.id
                ? layerColor.opacity(0.1)
                : Color.clear
        )
    }

    private func validationIssueRow(_ issue: ValidationIssue) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(issue.message)
                .font(.caption)
                .lineLimit(2)

            if let path = issue.path {
                Text(path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func recentLocationRow(_ location: AppState.RecentLocation) -> some View {
        Button {
            appState.openRecent(location)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(location.subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func matchesSearch(_ node: SpecNode) -> Bool {
        let query = appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return true
        }

        let haystacks = [
            node.id,
            node.name,
            node.file ?? "",
            node.description ?? "",
        ]

        return haystacks.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Helpers

    private func iconForEntryPointType(_ type: String) -> String {
        switch type.lowercased() {
        case "http": return "network"
        case "cli": return "terminal"
        case "event": return "bolt"
        case "cron": return "clock"
        default: return "arrow.right.circle"
        }
    }
}
