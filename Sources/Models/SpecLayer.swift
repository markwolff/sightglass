import Foundation

/// A layer groups related nodes (e.g., API Layer, Business Logic, Data Access).
public struct SpecLayer: Codable, Identifiable, Hashable {
    /// Unique identifier for this layer (e.g., "api")
    public let id: String

    /// Human-readable name (e.g., "API Layer")
    public let name: String

    /// Hex color string for rendering this layer (e.g., "#4A90D9")
    public let color: String

    /// Vertical order for rendering (0 = top).
    public let rank: Int
}
