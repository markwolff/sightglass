import Foundation

public struct SpecFlow: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String?
    public let trigger: SpecFlowTrigger?
    public let steps: [SpecFlowStep]
}

public struct SpecFlowTrigger: Codable, Hashable {
    public let type: String
    public let method: String?
    public let path: String?
}

public struct SpecFlowStep: Codable, Identifiable, Hashable {
    public var id: String { "\(from)->\(to)#\(sequence)" }

    public let from: String
    public let to: String
    public let label: String
    public let dataType: String?
    public let sequence: Int
    public let async: Bool?

    enum CodingKeys: String, CodingKey {
        case from
        case to
        case label
        case dataType = "data_type"
        case sequence
        case async
    }
}
