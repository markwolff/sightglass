import Foundation

public struct SpecTypeDefinition: Codable, Identifiable, Hashable {
    public let id: String
    public let description: String?
    public let fields: [SpecTypeField]?
}

public struct SpecTypeField: Codable, Identifiable, Hashable {
    public var id: String { name }

    public let name: String
    public let type: String
    public let required: Bool?
}
