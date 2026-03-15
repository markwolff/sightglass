import Foundation

/// An entry point into the system (HTTP endpoint, CLI command, event handler, etc.).
struct EntryPoint: Codable, Identifiable, Hashable {
    /// Computed identifier from node and path/type
    var id: String { "\(node)-\(type)-\(path ?? "unknown")" }

    /// The node ID this entry point belongs to
    let node: String

    /// The type of entry point (e.g., "http", "cli", "event", "cron")
    let type: String

    /// HTTP method if applicable (e.g., "GET", "POST")
    let method: String?

    /// URL path or command name
    let path: String?

    /// Description of what this entry point does
    let description: String?

    enum CodingKeys: String, CodingKey {
        case node
        case type
        case method
        case path
        case description
    }
}
