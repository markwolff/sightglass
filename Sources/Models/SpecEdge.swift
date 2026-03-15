import Foundation

/// An edge representing a data flow or dependency between two nodes.
struct SpecEdge: Codable, Identifiable, Hashable {
    /// Computed unique identifier from source and target
    var id: String { "\(from)->\(to)" }

    /// The source node ID
    let from: String

    /// The target node ID
    let to: String

    /// Human-readable label describing the relationship
    let label: String?

    /// The data type being passed along this edge
    let dataType: String?

    /// Whether this is an async/event-driven connection
    let async: Bool?

    enum CodingKeys: String, CodingKey {
        case from
        case to
        case label
        case dataType = "data_type"
        case async
    }
}
