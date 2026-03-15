import Foundation

struct FixtureManifest: Decodable {
    let specs: [SpecFixture]
    let repos: [RepoFixture]
}

struct SpecFixture: Decodable {
    let id: String
    let path: String
    let repo: String?
    let expected: FixtureCounts
    let validation: ValidationExpectation?
    let snapshot: String?
}

struct RepoFixture: Decodable {
    let id: String
    let path: String
    let pairedSpec: String?
    let expected: FixtureCounts
}

struct FixtureCounts: Decodable, Equatable {
    let layers: Int
    let nodes: Int
    let edges: Int
    let entryPoints: Int
    let flows: Int
}

struct ValidationExpectation: Decodable {
    let fatalCodes: [String]
    let warningCodes: [String]
}

enum FixtureLoader {
    static let repoRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    static let fixturesRoot = repoRoot.appendingPathComponent("Tests/Fixtures", isDirectory: true)

    static func manifest() throws -> FixtureManifest {
        try decodeJSON(FixtureManifest.self, at: "fixture-manifest.json")
    }

    static func fixtureURL(_ relativePath: String) -> URL {
        fixturesRoot.appendingPathComponent(relativePath)
    }

    static func repoURL(_ relativePath: String) -> URL {
        fixtureURL(relativePath)
    }

    static func loadString(at relativePath: String) throws -> String {
        try String(contentsOf: fixtureURL(relativePath), encoding: .utf8)
    }

    static func decodeJSON<T: Decodable>(_ type: T.Type, at relativePath: String) throws -> T {
        let data = try Data(contentsOf: fixtureURL(relativePath))
        return try JSONDecoder().decode(type, from: data)
    }
}
