import Foundation

public struct ValidationResult: Codable, Hashable {
    public var fatalErrors: [ValidationIssue] = []
    public var warnings: [ValidationIssue] = []
    public var remediationHints: [String] = []

    public init() {}

    public var isValid: Bool {
        fatalErrors.isEmpty
    }

    mutating func append(_ issue: ValidationIssue) {
        switch issue.severity {
        case .fatal:
            fatalErrors.append(issue)
        case .warning:
            warnings.append(issue)
        }

        if let hint = issue.hint, !remediationHints.contains(hint) {
            remediationHints.append(hint)
        }
    }

    public var summary: String {
        var lines: [String] = []

        if !fatalErrors.isEmpty {
            lines.append("Fatal validation errors:")
            lines.append(contentsOf: fatalErrors.map(\.summaryLine))
        }

        if !warnings.isEmpty {
            lines.append("Warnings:")
            lines.append(contentsOf: warnings.map(\.summaryLine))
        }

        return lines.joined(separator: "\n")
    }
}

public struct ValidationIssue: Codable, Hashable, Identifiable {
    public enum Severity: String, Codable {
        case fatal
        case warning
    }

    public var id: String {
        [severity.rawValue, code, path, message].compactMap { $0 }.joined(separator: "|")
    }

    public let severity: Severity
    public let code: String
    public let message: String
    public let path: String?
    public let hint: String?

    var summaryLine: String {
        let location = path.map { "\($0): " } ?? ""
        return "- \(location)\(message)"
    }
}
