import Foundation
import Yams

/// Parses YAML spec files into CodeSpec models.
struct SpecParser {
    /// Parses a YAML spec file at the given URL into a CodeSpec.
    ///
    /// - Parameter fileURL: The file URL of the YAML spec to parse.
    /// - Returns: A parsed CodeSpec model.
    /// - Throws: If the file cannot be read or the YAML is malformed.
    static func parse(fileURL: URL) throws -> CodeSpec {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: fileURL)
        return try parse(data: data)
    }

    /// Parses YAML data into a CodeSpec.
    ///
    /// - Parameter data: Raw YAML data.
    /// - Returns: A parsed CodeSpec model.
    /// - Throws: If the YAML is malformed or doesn't match the spec schema.
    static func parse(data: Data) throws -> CodeSpec {
        let decoder = YAMLDecoder()
        let spec = try decoder.decode(CodeSpec.self, from: data)
        return spec
    }

    /// Parses a YAML string into a CodeSpec.
    ///
    /// - Parameter yamlString: A YAML-formatted string.
    /// - Returns: A parsed CodeSpec model.
    /// - Throws: If the YAML is malformed or doesn't match the spec schema.
    static func parse(yamlString: String) throws -> CodeSpec {
        let decoder = YAMLDecoder()
        let spec = try decoder.decode(CodeSpec.self, from: yamlString)
        return spec
    }

    /// Validates a CodeSpec for internal consistency.
    ///
    /// Checks that all edge references point to existing nodes,
    /// all node layer references point to existing layers, etc.
    ///
    /// - Parameter spec: The spec to validate.
    /// - Returns: A list of validation warnings (empty if valid).
    static func validate(_ spec: CodeSpec) -> [String] {
        var warnings: [String] = []

        let nodeIDs = Set(spec.nodes.map(\.id))
        let layerIDs = Set(spec.layers.map(\.id))

        // Check that all nodes reference valid layers
        for node in spec.nodes {
            if !layerIDs.contains(node.layer) {
                warnings.append("Node '\(node.id)' references unknown layer '\(node.layer)'")
            }
        }

        // Check that all edges reference valid nodes
        for edge in spec.edges {
            if !nodeIDs.contains(edge.from) {
                warnings.append("Edge from '\(edge.from)' references unknown node")
            }
            if !nodeIDs.contains(edge.to) {
                warnings.append("Edge to '\(edge.to)' references unknown node")
            }
        }

        // Check that all entry points reference valid nodes
        if let entryPoints = spec.entryPoints {
            for ep in entryPoints {
                if !nodeIDs.contains(ep.node) {
                    warnings.append("Entry point references unknown node '\(ep.node)'")
                }
            }
        }

        return warnings
    }
}
