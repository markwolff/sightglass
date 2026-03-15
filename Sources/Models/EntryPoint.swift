import Foundation

/// An entry point into the system (HTTP endpoint, CLI command, event handler, etc.).
public struct EntryPoint: Codable, Identifiable, Hashable {
    /// Computed identifier from node and path/type
    public var id: String { "\(node)-\(type)-\(path ?? "unknown")" }

    /// The node ID this entry point belongs to
    public let node: String

    /// The type of entry point (e.g., "http", "cli", "event", "cron")
    public let type: String

    /// HTTP method if applicable (e.g., "GET", "POST")
    public let method: String?

    /// URL path or command name
    public let path: String?

    /// Description of what this entry point does
    public let description: String?

    /// Optional request payload type.
    public let requestType: String?

    /// Optional response payload type.
    public let responseType: String?

    enum CodingKeys: String, CodingKey {
        case node
        case type
        case method
        case path
        case description
        case requestType = "request_type"
        case responseType = "response_type"
    }
}
