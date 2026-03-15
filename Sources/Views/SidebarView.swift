import SwiftUI
import SightglassCore

/// Sidebar showing repository context, viewer controls, and node navigation.
struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            workspaceSection
            validationSection

            if let spec = appState.currentSpec {
                specInfoSection(spec)
                exploreSection(spec)
                flowSection(spec)
                layersControlSection(spec)
                entryPointsSection(spec)
                searchResultsSection(spec)
                layersSection(spec)
            }

            recentLocationsSection
            workspaceActionsSection
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

    private func specInfoSection(_ spec: CodeSpec) -> some View {
        Section("Project") {
            LabeledContent("Name", value: spec.name)
            LabeledContent("Version", value: "\(spec.version)")
            LabeledContent("Nodes", value: "\(spec.nodes.count)")
            LabeledContent("Edges", value: "\(spec.edges.count)")
        }
    }

    private func exploreSection(_ spec: CodeSpec) -> some View {
        let matches = matchingNodes(in: spec)

        return Section("Explore") {
            TextField("Search nodes, files, or owners", text: $appState.searchQuery)
                .textFieldStyle(.roundedBorder)

            if isSearching {
                Label(
                    "\(matches.count) match\(matches.count == 1 ? "" : "es")",
                    systemImage: matches.isEmpty ? "magnifyingglass" : "line.3.horizontal.decrease.circle"
                )
                .font(.caption)
                .foregroundStyle(matches.isEmpty ? Color.secondary : Color.accentColor)
            }
        }
    }

    private func flowSection(_ spec: CodeSpec) -> some View {
        Group {
            if let flows = spec.flows, !flows.isEmpty {
                Section("Flows") {
                    Picker("Selected Flow", selection: selectedFlowBinding) {
                        Text("All Flows").tag(Optional<String>.none)

                        ForEach(flows) { flow in
                            Text(flow.name).tag(Optional(flow.id))
                        }
                    }
                    .pickerStyle(.menu)

                    if let selectedFlow = appState.selectedFlow {
                        if let description = selectedFlow.description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let trigger = selectedFlow.trigger {
                            LabeledContent("Trigger", value: flowTriggerText(trigger))
                        }

                        ForEach(selectedFlow.steps.sorted { $0.sequence < $1.sequence }) { step in
                            Button {
                                appState.selectNode(id: step.to)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(step.sequence). \(nodeNameForID(step.from)) -> \(nodeNameForID(step.to))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(step.label)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func layersControlSection(_ spec: CodeSpec) -> some View {
        Section("Layers") {
            HStack {
                Button("Show All") {
                    appState.showAllLayers()
                }
                .buttonStyle(.borderless)

                Button("Hide All") {
                    appState.hideAllLayers()
                }
                .buttonStyle(.borderless)
            }

            ForEach(spec.layers) { layer in
                Toggle(isOn: layerVisibilityBinding(for: layer.id)) {
                    HStack {
                        Circle()
                            .fill(layer.swiftUIColor)
                            .frame(width: 8, height: 8)

                        Text(layer.name)

                        Spacer()

                        Text("\(nodeCount(in: spec, for: layer.id))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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

                                VStack(alignment: .leading, spacing: 2) {
                                    if let method = ep.method, let path = ep.path {
                                        Text("\(method) \(path)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    } else if let path = ep.path {
                                        Text(path)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    } else {
                                        Text(ep.type.uppercased())
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }

                                    Text(nodeNameForID(ep.node))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            appState.activeEntryPointID == ep.id
                                ? Color.orange.opacity(0.12)
                                : Color.clear
                        )
                    }
                }
            }
        }
    }

    private func searchResultsSection(_ spec: CodeSpec) -> some View {
        Group {
            if isSearching {
                let matches = matchingNodes(in: spec)

                Section("Matches") {
                    if matches.isEmpty {
                        Text("No nodes match the current search.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matches) { node in
                            nodeRow(
                                node,
                                layerColor: layerColor(for: node.layer),
                                showLayerName: true
                            )
                        }
                    }
                }
            }
        }
    }

    private func layersSection(_ spec: CodeSpec) -> some View {
        Group {
            if !isSearching {
                if appState.visibleLayerIDs.isEmpty {
                    Section("Visible Layers") {
                        Text("No layers are visible. Use the toggles above to bring layers back into the diagram.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(spec.layers.filter { appState.visibleLayerIDs.contains($0.id) }) { layer in
                        Section(layer.name) {
                            let layerNodes = spec.nodes.filter { $0.layer == layer.id }

                            ForEach(layerNodes) { node in
                                nodeRow(node, layerColor: layer.swiftUIColor)
                            }
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

    private var workspaceActionsSection: some View {
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

    // MARK: - Rows

    private func nodeRow(
        _ node: SpecNode,
        layerColor: Color,
        showLayerName: Bool = false
    ) -> some View {
        Button {
            appState.selectNode(id: node.id)
        } label: {
            HStack {
                Circle()
                    .fill(layerColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    if let subtitle = nodeSubtitle(for: node, showLayerName: showLayerName) {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if appState.activeEntryPoint?.node == node.id {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.orange)
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

    // MARK: - Helpers

    private var isSearching: Bool {
        !appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedFlowBinding: Binding<String?> {
        Binding(
            get: { appState.selectedFlowID },
            set: { appState.selectFlow(id: $0) }
        )
    }

    private func layerVisibilityBinding(for layerID: String) -> Binding<Bool> {
        Binding(
            get: { appState.visibleLayerIDs.contains(layerID) },
            set: { appState.setLayerVisibility($0, for: layerID) }
        )
    }

    private func matchingNodes(in spec: CodeSpec) -> [SpecNode] {
        spec.nodes.filter(matchesSearch)
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
            node.technology ?? "",
            node.owner ?? "",
            node.lifecycle ?? "",
            node.types?.joined(separator: " ") ?? "",
            node.methods?.joined(separator: " ") ?? "",
        ]

        return haystacks.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func nodeSubtitle(for node: SpecNode, showLayerName: Bool) -> String? {
        var components: [String] = []

        if showLayerName, let layerName = appState.currentSpec?.layers.first(where: { $0.id == node.layer })?.name {
            components.append(layerName)
        }

        if let file = node.file {
            components.append(file)
        } else if let technology = node.technology {
            components.append(technology)
        }

        return components.isEmpty ? nil : components.joined(separator: " | ")
    }

    private func nodeNameForID(_ id: String) -> String {
        appState.currentSpec?.nodes.first(where: { $0.id == id })?.name ?? id
    }

    private func nodeCount(in spec: CodeSpec, for layerID: String) -> Int {
        spec.nodes.count(where: { $0.layer == layerID })
    }

    private func layerColor(for layerID: String) -> Color {
        appState.currentSpec?.layers.first(where: { $0.id == layerID })?.swiftUIColor ?? .gray
    }

    private func flowTriggerText(_ trigger: SpecFlowTrigger) -> String {
        let parts = [
            trigger.type.uppercased(),
            trigger.method,
            trigger.path,
        ].compactMap { $0 }

        return parts.joined(separator: " | ")
    }

    private func iconForEntryPointType(_ type: String) -> String {
        switch type.lowercased() {
        case "http":
            return "network"
        case "cli":
            return "terminal"
        case "event":
            return "bolt"
        case "cron":
            return "clock"
        default:
            return "arrow.right.circle"
        }
    }
}
