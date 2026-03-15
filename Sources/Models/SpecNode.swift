import Foundation

/// A node in the code architecture graph representing a module, service, or component.
public struct SpecNode: Codable, Identifiable, Hashable {
    /// Unique identifier for this node (e.g., "auth-controller")
    public let id: String

    /// Human-readable name (e.g., "AuthController")
    public let name: String

    /// The layer this node belongs to (references a SpecLayer.id)
    public let layer: String

    /// File path within the analyzed project
    public let file: String?

    /// Description of what this node does
    public let description: String?

    /// Optional framework or runtime label shown in the UI.
    public let technology: String?

    /// Optional owning team or group.
    public let owner: String?

    /// Optional lifecycle marker such as production or deprecated.
    public let lifecycle: String?

    /// Optional list of key types/interfaces this node exposes
    public let types: [String]?

    /// Optional list of methods or functions this node provides
    public let methods: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case layer
        case file
        case description
        case technology
        case owner
        case lifecycle
        case types
        case methods
    }
}
