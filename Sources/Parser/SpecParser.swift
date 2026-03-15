import Foundation
import Yams

/// Parses YAML spec files into normalized CodeFlow v2 models.
public struct SpecParser {
    private static let supportedVersion = 2

    private static let allowedEdgeTypes: Set<String> = [
        "calls", "triggers", "reads", "writes", "publishes", "subscribes", "returns"
    ]

    private static let allowedProtocols: Set<String> = [
        "function", "https", "grpc", "graphql", "kafka", "amqp", "websocket", "jdbc", "redis"
    ]

    private static let allowedNodeLifecycles: Set<String> = [
        "production", "experimental", "deprecated"
    ]

    private static let allowedEntryPointTypes: Set<String> = [
        "http", "grpc", "graphql", "cli", "event", "cron", "websocket"
    ]

    private static let allowedFlowTriggerTypes: Set<String> = [
        "http", "event", "cron", "manual"
    ]

    /// Parses a YAML spec file at the given URL into a normalized CodeSpec.
    public static func parse(fileURL: URL) throws -> CodeSpec {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: fileURL)
        return try parse(data: data)
    }

    /// Parses YAML data into a normalized CodeSpec.
    public static func parse(data: Data) throws -> CodeSpec {
        let yamlString = String(decoding: data, as: UTF8.self)
        return try parse(yamlString: yamlString)
    }

    /// Parses a YAML string into a normalized CodeSpec.
    public static func parse(yamlString: String) throws -> CodeSpec {
        let version = try detectedVersion(in: yamlString)
        let decoder = YAMLDecoder()

        if version == 1 {
            let legacySpec = try decoder.decode(LegacyCodeSpecV1.self, from: yamlString)
            return migrateV1Spec(legacySpec)
        }

        let spec = try decoder.decode(CodeSpec.self, from: yamlString)
        return spec
    }

    /// Encodes a CodeSpec back into YAML for persistence.
    public static func encode(_ spec: CodeSpec) throws -> String {
        let encoder = YAMLEncoder()
        return try encoder.encode(spec)
    }

    /// Validates a CodeSpec for structural consistency and file-backed integrity.
    public static func validate(_ spec: CodeSpec, repositoryRoot: URL? = nil) -> ValidationResult {
        var result = ValidationResult()

        appendDuplicateIDIssues(in: spec.layers.map(\.id), label: "layer", pathRoot: "layers", into: &result)
        appendDuplicateIDIssues(in: spec.nodes.map(\.id), label: "node", pathRoot: "nodes", into: &result)
        appendDuplicateIDIssues(in: spec.flows?.map(\.id) ?? [], label: "flow", pathRoot: "flows", into: &result)
        appendDuplicateIDIssues(in: spec.types?.map(\.id) ?? [], label: "type", pathRoot: "types", into: &result)

        let nodeIDs = Set(spec.nodes.map(\.id))
        let layerIDs = Set(spec.layers.map(\.id))
        var seenLayerRanks: [Int: String] = [:]

        for (index, layer) in spec.layers.enumerated() {
            let path = "layers[\(index)]"

            if layer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "empty_layer_name",
                        message: "Layer '\(layer.id)' has an empty name.",
                        path: "\(path).name",
                        hint: "Provide a non-empty display name for every layer."
                    )
                )
            }

            if !isValidHexColor(layer.color) {
                result.append(
                    ValidationIssue(
                        severity: .warning,
                        code: "invalid_layer_color",
                        message: "Layer '\(layer.id)' uses invalid color '\(layer.color)'.",
                        path: "\(path).color",
                        hint: "Use a 6-digit hex color like '#4A90D9'."
                    )
                )
            }

            if layer.rank < 0 {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "invalid_layer_rank",
                        message: "Layer '\(layer.id)' has invalid rank \(layer.rank).",
                        path: "\(path).rank",
                        hint: "Layer ranks must be zero or greater."
                    )
                )
            }

            if let otherLayerID = seenLayerRanks[layer.rank] {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "duplicate_layer_rank",
                        message: "Layer '\(layer.id)' reuses rank \(layer.rank), which is already assigned to '\(otherLayerID)'.",
                        path: "\(path).rank",
                        hint: "Assign each layer a unique rank so vertical ordering stays deterministic."
                    )
                )
            } else {
                seenLayerRanks[layer.rank] = layer.id
            }
        }

        for (index, node) in spec.nodes.enumerated() {
            let path = "nodes[\(index)]"

            if node.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "empty_node_name",
                        message: "Node '\(node.id)' has an empty name.",
                        path: "\(path).name",
                        hint: "Provide a non-empty display name for every node."
                    )
                )
            }

            if !layerIDs.contains(node.layer) {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "unknown_layer_reference",
                        message: "Node '\(node.id)' references unknown layer '\(node.layer)'.",
                        path: "\(path).layer",
                        hint: "Point the node at a valid layer id from the layers section."
                    )
                )
            }

            if let lifecycle = node.lifecycle,
               !allowedNodeLifecycles.contains(lifecycle) {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "invalid_node_lifecycle",
                        message: "Node '\(node.id)' uses invalid lifecycle '\(lifecycle)'.",
                        path: "\(path).lifecycle",
                        hint: "Use one of: \(allowedNodeLifecycles.sorted().joined(separator: ", "))."
                    )
                )
            }

            if let file = node.file,
               let repositoryRoot,
               !FileManager.default.fileExists(atPath: repositoryRoot.appendingPathComponent(file).path) {
                result.append(
                    ValidationIssue(
                        severity: .warning,
                        code: "missing_node_file",
                        message: "Node '\(node.id)' points to missing file '\(file)'.",
                        path: "\(path).file",
                        hint: "Fix the relative path or move the spec next to the analyzed repository root."
                    )
                )
            }
        }

        for (index, edge) in spec.edges.enumerated() {
            let path = "edges[\(index)]"

            if !nodeIDs.contains(edge.from) {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "unknown_edge_source",
                        message: "Edge source '\(edge.from)' does not match any node id.",
                        path: "\(path).from",
                        hint: "Use a source node id that exists in the nodes section."
                    )
                )
            }

            if !nodeIDs.contains(edge.to) {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "unknown_edge_target",
                        message: "Edge target '\(edge.to)' does not match any node id.",
                        path: "\(path).to",
                        hint: "Use a target node id that exists in the nodes section."
                    )
                )
            }

            if let type = edge.type,
               !allowedEdgeTypes.contains(type) {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "invalid_edge_type",
                        message: "Edge '\(edge.id)' uses invalid relationship type '\(type)'.",
                        path: "\(path).type",
                        hint: "Use one of: \(allowedEdgeTypes.sorted().joined(separator: ", "))."
                    )
                )
            }

            if let protocolName = edge.protocolName,
               !allowedProtocols.contains(protocolName) {
                result.append(
                    ValidationIssue(
                        severity: .fatal,
                        code: "invalid_edge_protocol",
                        message: "Edge '\(edge.id)' uses invalid protocol '\(protocolName)'.",
                        path: "\(path).protocol",
                        hint: "Use one of: \(allowedProtocols.sorted().joined(separator: ", "))."
                    )
                )
            }
        }

        if let entryPoints = spec.entryPoints {
            for (index, entryPoint) in entryPoints.enumerated() {
                let path = "entry_points[\(index)]"

                if !nodeIDs.contains(entryPoint.node) {
                    result.append(
                        ValidationIssue(
                            severity: .fatal,
                            code: "unknown_entry_point_node",
                            message: "Entry point references unknown node '\(entryPoint.node)'.",
                            path: "\(path).node",
                            hint: "Attach entry points to a node id that exists in the nodes section."
                        )
                    )
                }

                if !allowedEntryPointTypes.contains(entryPoint.type) {
                    result.append(
                        ValidationIssue(
                            severity: .fatal,
                            code: "invalid_entry_point_type",
                            message: "Entry point '\(entryPoint.id)' uses invalid type '\(entryPoint.type)'.",
                            path: "\(path).type",
                            hint: "Use one of: \(allowedEntryPointTypes.sorted().joined(separator: ", "))."
                        )
                    )
                }
            }
        }

        if let flows = spec.flows {
            for (flowIndex, flow) in flows.enumerated() {
                let flowPath = "flows[\(flowIndex)]"

                if flow.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(
                        ValidationIssue(
                            severity: .fatal,
                            code: "empty_flow_name",
                            message: "Flow '\(flow.id)' has an empty name.",
                            path: "\(flowPath).name",
                            hint: "Provide a non-empty display name for every flow."
                        )
                    )
                }

                if let trigger = flow.trigger,
                   !allowedFlowTriggerTypes.contains(trigger.type) {
                    result.append(
                        ValidationIssue(
                            severity: .fatal,
                            code: "invalid_flow_trigger_type",
                            message: "Flow '\(flow.id)' uses invalid trigger type '\(trigger.type)'.",
                            path: "\(flowPath).trigger.type",
                            hint: "Use one of: \(allowedFlowTriggerTypes.sorted().joined(separator: ", "))."
                        )
                    )
                }

                let orderedSequences = flow.steps.map(\.sequence).sorted()
                let expectedSequences = Array(1...flow.steps.count)
                if orderedSequences != expectedSequences {
                    result.append(
                        ValidationIssue(
                            severity: .fatal,
                            code: "invalid_flow_sequence",
                            message: "Flow '\(flow.id)' steps must use a continuous sequence from 1 through \(flow.steps.count).",
                            path: "\(flowPath).steps",
                            hint: "Renumber flow steps so sequence values are continuous and unique."
                        )
                    )
                }

                for (stepIndex, step) in flow.steps.enumerated() {
                    let stepPath = "\(flowPath).steps[\(stepIndex)]"

                    if !nodeIDs.contains(step.from) {
                        result.append(
                            ValidationIssue(
                                severity: .fatal,
                                code: "unknown_flow_source",
                                message: "Flow '\(flow.id)' references unknown source node '\(step.from)'.",
                                path: "\(stepPath).from",
                                hint: "Use a source node id that exists in the nodes section."
                            )
                        )
                    }

                    if !nodeIDs.contains(step.to) {
                        result.append(
                            ValidationIssue(
                                severity: .fatal,
                                code: "unknown_flow_target",
                                message: "Flow '\(flow.id)' references unknown target node '\(step.to)'.",
                                path: "\(stepPath).to",
                                hint: "Use a target node id that exists in the nodes section."
                            )
                        )
                    }
                }
            }
        }

        return result
    }

    private static func detectedVersion(in yamlString: String) throws -> Int {
        guard let document = try load(yaml: yamlString) as? [AnyHashable: Any] else {
            return supportedVersion
        }

        if let version = document["version"] as? Int {
            return version
        }

        if let version = document["version"] as? NSNumber {
            return version.intValue
        }

        return supportedVersion
    }

    private static func appendDuplicateIDIssues(
        in ids: [String],
        label: String,
        pathRoot: String,
        into result: inout ValidationResult
    ) {
        var seen: Set<String> = []
        var duplicates: Set<String> = []

        for id in ids {
            if !seen.insert(id).inserted {
                duplicates.insert(id)
            }
        }

        for duplicate in duplicates.sorted() {
            result.append(
                ValidationIssue(
                    severity: .fatal,
                    code: "duplicate_\(label)_id",
                    message: "Duplicate \(label) id '\(duplicate)'.",
                    path: pathRoot,
                    hint: "Make every \(label) id unique within the spec."
                )
            )
        }
    }

    private static func isValidHexColor(_ color: String) -> Bool {
        let trimmed = color.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        return hex.count == 6 && hex.allSatisfy(\.isHexDigit)
    }

    private static func migrateV1Spec(_ legacySpec: LegacyCodeSpecV1) -> CodeSpec {
        let migratedLayers = legacySpec.layers.enumerated().map { index, layer in
            SpecLayer(id: layer.id, name: layer.name, color: layer.color, rank: index)
        }

        let migratedNodes = legacySpec.nodes.map { node in
            SpecNode(
                id: node.id,
                name: node.name,
                layer: node.layer,
                file: node.file,
                description: node.description,
                technology: nil,
                owner: nil,
                lifecycle: nil,
                types: node.types,
                methods: node.methods
            )
        }

        let migratedEdges = legacySpec.edges.map { edge in
            SpecEdge(
                from: edge.from,
                to: edge.to,
                label: edge.label,
                dataType: edge.dataType,
                type: nil,
                async: edge.async,
                protocolName: nil
            )
        }

        return CodeSpec(
            name: legacySpec.name,
            version: supportedVersion,
            analyzedAt: legacySpec.analyzedAt,
            commitSHA: nil,
            metadata: nil,
            layers: migratedLayers,
            nodes: migratedNodes,
            edges: migratedEdges,
            entryPoints: legacySpec.entryPoints,
            flows: nil,
            types: nil
        )
    }
}

private struct LegacyCodeSpecV1: Codable {
    let name: String
    let version: Int
    let analyzedAt: Date?
    let layers: [LegacySpecLayerV1]
    let nodes: [LegacySpecNodeV1]
    let edges: [LegacySpecEdgeV1]
    let entryPoints: [EntryPoint]?

    enum CodingKeys: String, CodingKey {
        case name
        case version
        case analyzedAt = "analyzed_at"
        case layers
        case nodes
        case edges
        case entryPoints = "entry_points"
    }
}

private struct LegacySpecLayerV1: Codable {
    let id: String
    let name: String
    let color: String
}

private struct LegacySpecNodeV1: Codable {
    let id: String
    let name: String
    let layer: String
    let file: String?
    let description: String?
    let types: [String]?
    let methods: [String]?
}

private struct LegacySpecEdgeV1: Codable {
    let from: String
    let to: String
    let label: String?
    let dataType: String?
    let async: Bool?

    enum CodingKeys: String, CodingKey {
        case from
        case to
        case label
        case dataType = "data_type"
        case async
    }
}
