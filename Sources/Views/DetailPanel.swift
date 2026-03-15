import SwiftUI

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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(node.name)
                    .font(.headline)
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
                    // Layer
                    if let layer = appState.currentSpec?.layers.first(where: { $0.id == node.layer }) {
                        detailRow(label: "Layer", value: layer.name, color: layer.swiftUIColor)
                    }

                    // File
                    if let file = node.file {
                        detailRow(label: "File", value: file)
                    }

                    // Description
                    if let description = node.description {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(description)
                                .font(.body)
                        }
                    }

                    // Types
                    if let types = node.types, !types.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Types")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(types, id: \.self) { type in
                                Text(type)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }

                    // Methods
                    if let methods = node.methods, !methods.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Methods")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(methods, id: \.self) { method in
                                Text(method)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }

                    // Connected edges
                    connectionsSection(for: node)

                    // Entry points
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

    // MARK: - Connections

    private func connectionsSection(for node: SpecNode) -> some View {
        Group {
            if let spec = appState.currentSpec {
                let incoming = spec.edges.filter { $0.to == node.id }
                let outgoing = spec.edges.filter { $0.from == node.id }

                if !incoming.isEmpty || !outgoing.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connections")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(incoming) { edge in
                            HStack {
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(nodeNameForID(edge.from))
                                    .font(.caption)
                                if let label = edge.label {
                                    Text("(\(label))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        ForEach(outgoing) { edge in
                            HStack {
                                Image(systemName: "arrow.left")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text(nodeNameForID(edge.to))
                                    .font(.caption)
                                if let label = edge.label {
                                    Text("(\(label))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
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
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func nodeNameForID(_ id: String) -> String {
        appState.currentSpec?.nodes.first(where: { $0.id == id })?.name ?? id
    }
}
