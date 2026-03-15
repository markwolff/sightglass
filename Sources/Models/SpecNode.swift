import Foundation

/// A node in the code architecture graph representing a module, service, or component.
struct SpecNode: Codable, Identifiable, Hashable {
    /// Unique identifier for this node (e.g., "auth-controller")
    let id: String

    /// Human-readable name (e.g., "AuthController")
    let name: String

    /// The layer this node belongs to (references a SpecLayer.id)
    let layer: String

    /// File path within the analyzed project
    let file: String?

    /// Description of what this node does
    let description: String?

    /// Optional list of key types/interfaces this node exposes
    let types: [String]?

    /// Optional list of methods or functions this node provides
    let methods: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case layer
        case file
        case description
        case types
        case methods
    }
}
