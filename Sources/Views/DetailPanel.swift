import SwiftUI
import SightglassCore
#if canImport(AppKit)
import AppKit
#endif

/// A panel that shows detailed information about the currently selected node.
/// Appears as an overlay on the right side of the diagram.
struct DetailPanel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let node = appState.selectedNode {
                nodeDetail(node)
            }
        }
    }

    private func nodeDetail(_ node: SpecNode) -> some View {
        let incoming = incomingEdges(for: node)
        let outgoing = outgoingEdges(for: node)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.name)
                        .font(.headline)

                    Text(node.id)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appState.clearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    layerSection(for: node)
                    metadataSection(for: node)
                    fileSection(for: node)

                    if let description = node.description {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(description)
                                .font(.body)
                        }
                    }

                    if let types = node.types, !types.isEmpty {
                        valueListSection(title: "Types", values: types)
                    }

                    if let methods = node.methods, !methods.isEmpty {
                        valueListSection(title: "Methods", values: methods)
                    }

                    if !incoming.isEmpty {
                        connectionsSection(
                            title: "Incoming",
                            edges: incoming,
                            node: node,
                            accent: .green
                        )
                    }

                    if !outgoing.isEmpty {
                        connectionsSection(
                            title: "Outgoing",
                            edges: outgoing,
                            node: node,
                            accent: .blue
                        )
                    }

                    entryPointsSection(for: node)
                }
                .padding()
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }

    // MARK: - Detail Row

    private func detailRow(label: String, value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Text(value)
                    .font(.body)
            }
        }
    }

    private func layerSection(for node: SpecNode) -> some View {
        Group {
            if let layer = appState.currentSpec?.layers.first(where: { $0.id == node.layer }) {
                detailRow(label: "Layer", value: layer.name, color: layer.swiftUIColor)
            } else {
                detailRow(label: "Layer", value: node.layer)
            }
        }
    }

    private func metadataSection(for node: SpecNode) -> some View {
        Group {
            if node.technology != nil || node.owner != nil || node.lifecycle != nil {
                VStack(alignment: .leading, spacing: 12) {
                    if let technology = node.technology {
                        detailRow(label: "Technology", value: technology)
                    }

                    if let owner = node.owner {
                        detailRow(label: "Owner", value: owner)
                    }

                    if let lifecycle = node.lifecycle {
                        detailRow(label: "Lifecycle", value: lifecycle)
                    }
                }
            }
        }
    }

    private func fileSection(for node: SpecNode) -> some View {
        Group {
            if let file = node.file {
                let resolvedURL = resolvedFileURL(for: file)
                let fileExists = resolvedURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false

                VStack(alignment: .leading, spacing: 8) {
                    Text("File")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(file)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)

                    Button {
                        openResolvedFile(for: file)
                    } label: {
                        Label(fileExists ? "Open File" : "Open File Unavailable", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!fileExists)
                }
            }
        }
    }

    private func valueListSection(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(values, id: \.self) { value in
                Text(value)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    // MARK: - Connections

    private func connectionsSection(
        title: String,
        edges: [SpecEdge],
        node: SpecNode,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(edges) { edge in
                connectionRow(edge, relativeTo: node, accent: accent)
            }
        }
    }

    private func connectionRow(_ edge: SpecEdge, relativeTo node: SpecNode, accent: Color) -> some View {
        let peerNodeID = edge.from == node.id ? edge.to : edge.from
        let peerName = nodeNameForID(peerNodeID)

        return Button {
            appState.selectNode(id: peerNodeID)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image(systemName: edge.from == node.id ? "arrow.up.right" : "arrow.down.left")
                        .font(.caption)
                        .foregroundStyle(accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(peerName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text(connectionSummary(for: edge))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    if let edgeType = edge.type {
                        Text(edgeType.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.12), in: Capsule())
                            .foregroundStyle(accent)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Entry Points

    private func entryPointsSection(for node: SpecNode) -> some View {
        Group {
            if let entryPoints = appState.currentSpec?.entryPoints?.filter({ $0.node == node.id }),
               !entryPoints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Entry Points")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(entryPoints) { ep in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)

                                if let method = ep.method, let path = ep.path {
                                    Text("\(method) \(path)")
                                        .font(.system(.caption, design: .monospaced))
                                } else if let path = ep.path {
                                    Text(path)
                                        .font(.system(.caption, design: .monospaced))
                                } else {
                                    Text(ep.type.uppercased())
                                        .font(.caption)
                                }
                            }

                            if let description = ep.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let requestType = ep.requestType {
                                Text("Request: \(requestType)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if let responseType = ep.responseType {
                                Text("Response: \(responseType)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func nodeNameForID(_ id: String) -> String {
        appState.currentSpec?.nodes.first(where: { $0.id == id })?.name ?? id
    }

    private func incomingEdges(for node: SpecNode) -> [SpecEdge] {
        appState.currentSpec?.edges.filter { $0.to == node.id } ?? []
    }

    private func outgoingEdges(for node: SpecNode) -> [SpecEdge] {
        appState.currentSpec?.edges.filter { $0.from == node.id } ?? []
    }

    private func connectionSummary(for edge: SpecEdge) -> String {
        let parts = [
            edge.label,
            edge.dataType.map { "Data: \($0)" },
            edge.protocolName.map { "Via: \($0)" },
            edge.async == true ? "Async" : nil,
        ].compactMap { $0 }

        return parts.isEmpty ? "Select to inspect connected node" : parts.joined(separator: " | ")
    }

    private func resolvedFileURL(for path: String) -> URL? {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        guard let rootURL = appState.currentRepoRoot else {
            return nil
        }

        return rootURL.appendingPathComponent(path).standardizedFileURL
    }

    private func openResolvedFile(for path: String) {
        guard let fileURL = resolvedFileURL(for: path) else {
            return
        }

        #if canImport(AppKit)
        NSWorkspace.shared.open(fileURL)
        #endif
    }
}
