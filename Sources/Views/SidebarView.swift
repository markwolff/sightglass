import SwiftUI
import SightglassCore

/// Sidebar showing the loaded spec's nodes organized by layer,
/// along with file loading controls.
struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            if let spec = appState.currentSpec {
                specInfoSection(spec)
                layersSection(spec)
                entryPointsSection(spec)
            } else {
                noSpecSection
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Sightglass")
    }

    // MARK: - Sections

    private func specInfoSection(_ spec: CodeSpec) -> some View {
        Section("Project") {
            LabeledContent("Name", value: spec.name)
            LabeledContent("Version", value: "\(spec.version)")
            LabeledContent("Nodes", value: "\(spec.nodes.count)")
            LabeledContent("Edges", value: "\(spec.edges.count)")
        }
    }

    private func layersSection(_ spec: CodeSpec) -> some View {
        ForEach(spec.layers) { layer in
            Section(layer.name) {
                let layerNodes = spec.nodes.filter { $0.layer == layer.id }
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
                }
            }
        }
    }

    private var noSpecSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text("No spec loaded")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Button("Open Spec File...") {
                    appState.showFilePicker = true
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
            appState.selectedNode?.id == node.id
                ? layerColor.opacity(0.1)
                : Color.clear
        )
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
