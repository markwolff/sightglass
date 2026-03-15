import Foundation

/// An edge representing a data flow or dependency between two nodes.
public struct SpecEdge: Codable, Identifiable, Hashable {
    /// Computed unique identifier from source and target
    public var id: String { "\(from)->\(to)" }

    /// The source node ID
    public let from: String

    /// The target node ID
    public let to: String

    /// Human-readable label describing the relationship
    public let label: String?

    /// The data type being passed along this edge
    public let dataType: String?

    /// Relationship type such as calls, writes, or publishes.
    public let type: String?

    /// Whether this is an async/event-driven connection
    public let async: Bool?

    /// Transport or protocol used by the relationship.
    public let protocolName: String?

    enum CodingKeys: String, CodingKey {
        case from
        case to
        case label
        case dataType = "data_type"
        case type
        case async
        case protocolName = "protocol"
    }
}
