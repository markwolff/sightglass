import Foundation
import SightglassCore

@main
enum SightglassHarnessMain {
    static func main() {
        do {
            let command = try HarnessCommand(arguments: Array(CommandLine.arguments.dropFirst()))
            try HarnessRunner().run(command)
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }
}

private struct HarnessRunner {
    private let fixturesRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Tests/Fixtures", isDirectory: true)

    func run(_ command: HarnessCommand) throws {
        let manifest = try loadManifest()
        try verifyRepositoryManifest(manifest)
        try verifyCanonicalFixtures(manifest)
        try verifyLayoutInvariants(manifest, updateSnapshots: command.updateSnapshots)

        let benchmarkReport = try benchmarkReport(for: manifest)
        if let outputPath = command.benchmarkOutputPath {
            let outputURL = URL(fileURLWithPath: outputPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            try writeJSON(benchmarkReport, to: outputURL.standardizedFileURL)
        }

        print("Verification complete.")
        print("Fixtures: \(manifest.specs.count) specs, \(manifest.repos.count) repos")
        if let outputPath = command.benchmarkOutputPath {
            print("Benchmarks: \(outputPath)")
        }
    }

    private func verifyRepositoryManifest(_ manifest: FixtureManifest) throws {
        for repo in manifest.repos {
            let repoURL = fixturesRoot.appendingPathComponent(repo.path)
            guard FileManager.default.fileExists(atPath: repoURL.path) else {
                throw HarnessError("Missing repo fixture at \(repo.path)")
            }

            if let pairedSpecID = repo.pairedSpec,
               let spec = manifest.specs.first(where: { $0.id == pairedSpecID }) {
                guard spec.expected == repo.expected else {
                    throw HarnessError("Manifest counts for repo \(repo.id) do not match paired spec \(pairedSpecID)")
                }
            }
        }
    }

    private func verifyCanonicalFixtures(_ manifest: FixtureManifest) throws {
        for fixture in manifest.specs {
            let yaml = try String(contentsOf: fixturesRoot.appendingPathComponent(fixture.path), encoding: .utf8)
            let spec = try SpecParser.parse(yamlString: yaml)

            try require(spec.layers.count == fixture.expected.layers, "Unexpected layer count for \(fixture.id)")
            try require(spec.nodes.count == fixture.expected.nodes, "Unexpected node count for \(fixture.id)")
            try require(spec.edges.count == fixture.expected.edges, "Unexpected edge count for \(fixture.id)")
            try require((spec.entryPoints?.count ?? 0) == fixture.expected.entryPoints, "Unexpected entry point count for \(fixture.id)")
            try require((spec.flows?.count ?? 0) == fixture.expected.flows, "Unexpected flow count for \(fixture.id)")

            let repositoryRoot = fixture.repo.map { fixturesRoot.appendingPathComponent($0) }
            let validation = SpecParser.validate(spec, repositoryRoot: repositoryRoot)
            try require(
                validation.fatalErrors.map(\.code).sorted() == (fixture.validation?.fatalCodes.sorted() ?? []),
                "Unexpected fatal validation codes for \(fixture.id): \(validation.fatalErrors.map(\.code).sorted())"
            )
            try require(
                validation.warnings.map(\.code).sorted() == (fixture.validation?.warningCodes.sorted() ?? []),
                "Unexpected warning validation codes for \(fixture.id): \(validation.warnings.map(\.code).sorted())"
            )
        }
    }

    private func verifyLayoutInvariants(_ manifest: FixtureManifest, updateSnapshots: Bool) throws {
        let validFixtures = manifest.specs.filter { ($0.validation?.fatalCodes ?? []).isEmpty }

        for fixture in validFixtures {
            let yaml = try String(contentsOf: fixturesRoot.appendingPathComponent(fixture.path), encoding: .utf8)
            let spec = try SpecParser.parse(yamlString: yaml)
            let positions = GraphLayout(spec: spec).computePositions()
            try require(positions.count == spec.nodes.count, "Missing node positions for \(fixture.id)")

            try verifyLayerOrdering(spec: spec, positions: positions, fixtureID: fixture.id)
        }

        let largeFixture = try requireSpecFixture("large-graph", from: manifest)
        let largeSpec = try SpecParser.parse(
            yamlString: String(contentsOf: fixturesRoot.appendingPathComponent(largeFixture.path), encoding: .utf8)
        )
        let largePositions = GraphLayout(spec: largeSpec).computePositions()
        try verifyNoOverlap(positions: largePositions, fixtureID: largeFixture.id)
        try verifyDisconnectedNoise(positions: largePositions, fixtureID: largeFixture.id)

        let snapshotFixtures = manifest.specs.compactMap { fixture -> FixtureSpec? in
            fixture.snapshot == nil ? nil : fixture
        }

        for fixture in snapshotFixtures {
            let yaml = try String(contentsOf: fixturesRoot.appendingPathComponent(fixture.path), encoding: .utf8)
            let spec = try SpecParser.parse(yamlString: yaml)
            let positions = GraphLayout(spec: spec).computePositions()
            let snapshot = DiagramGeometrySnapshotBuilder.makeSnapshot(spec: spec, positions: positions)
            let snapshotURL = fixturesRoot.appendingPathComponent(try require(fixture.snapshot, "Missing snapshot path for \(fixture.id)"))
            let data = try encodedJSON(snapshot)

            if updateSnapshots {
                try data.write(to: snapshotURL, options: .atomic)
            }

            let expected = try Data(contentsOf: snapshotURL)
            try require(data == expected, "Geometry snapshot mismatch for \(fixture.id)")
        }
    }

    private func verifyLayerOrdering(spec: CodeSpec, positions: [String: CGPoint], fixtureID: String) throws {
        let orderedLayers = spec.layers.sorted { lhs, rhs in
            if lhs.rank == rhs.rank {
                return lhs.id < rhs.id
            }
            return lhs.rank < rhs.rank
        }

        var previousAverageY: CGFloat?
        for layer in orderedLayers {
            let layerPositions = spec.nodes
                .filter { $0.layer == layer.id }
                .compactMap { positions[$0.id]?.y }

            guard !layerPositions.isEmpty else { continue }
            let averageY = layerPositions.reduce(0, +) / CGFloat(layerPositions.count)
            if let previousAverageY {
                try require(previousAverageY < averageY, "Layer rank ordering collapsed for \(fixtureID)")
            }
            previousAverageY = averageY
        }
    }

    private func verifyNoOverlap(positions: [String: CGPoint], fixtureID: String) throws {
        let nodeSize = CGSize(width: 160, height: 60)
        let values = Array(positions.values)

        for i in 0..<values.count {
            for j in (i + 1)..<values.count {
                let dx = abs(values[i].x - values[j].x)
                let dy = abs(values[i].y - values[j].y)
                let separated = dx > nodeSize.width * 0.5 || dy > nodeSize.height * 0.5
                try require(separated, "Overlapping nodes in \(fixtureID)")
            }
        }
    }

    private func verifyDisconnectedNoise(positions: [String: CGPoint], fixtureID: String) throws {
        guard
            let authController = positions["auth-controller"],
            let orderController = positions["order-controller"],
            let orderService = positions["order-service"],
            let legacyScript = positions["legacy-admin-script"]
        else {
            throw HarnessError("Missing large-graph positions for disconnected noise check")
        }

        let centroid = CGPoint(
            x: (authController.x + orderController.x + orderService.x) / 3,
            y: (authController.y + orderController.y + orderService.y) / 3
        )
        let distance = hypot(legacyScript.x - centroid.x, legacyScript.y - centroid.y)
        try require(distance > 120, "Disconnected noise collapsed into main graph for \(fixtureID)")
    }

    private func benchmarkReport(for manifest: FixtureManifest) throws -> BenchmarkReport {
        let benchmarkFixtureIDs = ["minimal-valid", "layered-rest-service", "large-graph"]
        var records: [BenchmarkRecord] = []

        for fixtureID in benchmarkFixtureIDs {
            let fixture = try requireSpecFixture(fixtureID, from: manifest)
            let yaml = try String(contentsOf: fixturesRoot.appendingPathComponent(fixture.path), encoding: .utf8)
            let spec = try SpecParser.parse(yamlString: yaml)
            let repositoryRoot = fixture.repo.map { fixturesRoot.appendingPathComponent($0) }
            let positions = GraphLayout(spec: spec).computePositions()

            records.append(
                BenchmarkRecord(id: "\(fixture.id).parse", iterations: 25, averageMilliseconds: try benchmark(iterations: 25) {
                    _ = try SpecParser.parse(yamlString: yaml)
                })
            )
            records.append(
                BenchmarkRecord(id: "\(fixture.id).validate", iterations: 50, averageMilliseconds: benchmark(iterations: 50) {
                    _ = SpecParser.validate(spec, repositoryRoot: repositoryRoot)
                })
            )
            records.append(
                BenchmarkRecord(id: "\(fixture.id).layout", iterations: 15, averageMilliseconds: benchmark(iterations: 15) {
                    _ = GraphLayout(spec: spec).computePositions()
                })
            )
            records.append(
                BenchmarkRecord(id: "\(fixture.id).render", iterations: 50, averageMilliseconds: benchmark(iterations: 50) {
                    _ = DiagramGeometrySnapshotBuilder.makeSnapshot(spec: spec, positions: positions)
                })
            )
        }

        return BenchmarkReport(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            benchmarks: records
        )
    }

    private func benchmark(iterations: Int, work: () throws -> Void) rethrows -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            try work()
        }
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return elapsedMilliseconds / Double(iterations)
    }

    private func loadManifest() throws -> FixtureManifest {
        let data = try Data(contentsOf: fixturesRoot.appendingPathComponent("fixture-manifest.json"))
        return try JSONDecoder().decode(FixtureManifest.self, from: data)
    }

    private func encodedJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let parentDirectory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
        try encodedJSON(value).write(to: url, options: .atomic)
    }

    private func requireSpecFixture(_ id: String, from manifest: FixtureManifest) throws -> FixtureSpec {
        try require(manifest.specs.first(where: { $0.id == id }), "Missing fixture \(id)")
    }

    @discardableResult
    private func require(_ condition: Bool, _ message: String) throws -> Bool {
        guard condition else {
            throw HarnessError(message)
        }
        return condition
    }

    private func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw HarnessError(message)
        }
        return value
    }
}

private struct HarnessCommand {
    let updateSnapshots: Bool
    let benchmarkOutputPath: String?

    init(arguments: [String]) throws {
        var updateSnapshots = false
        var benchmarkOutputPath: String?
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "verify":
                break
            case "--update-snapshots":
                updateSnapshots = true
            case "--benchmark-output":
                index += 1
                guard index < arguments.count else {
                    throw HarnessError("Missing value for --benchmark-output")
                }
                benchmarkOutputPath = arguments[index]
            default:
                throw HarnessError("Unknown argument: \(arguments[index])")
            }
            index += 1
        }

        self.updateSnapshots = updateSnapshots
        self.benchmarkOutputPath = benchmarkOutputPath
    }
}

private struct FixtureManifest: Decodable {
    let specs: [FixtureSpec]
    let repos: [FixtureRepo]
}

private struct FixtureSpec: Decodable {
    let id: String
    let path: String
    let repo: String?
    let expected: FixtureCounts
    let validation: ValidationExpectation?
    let snapshot: String?
}

private struct FixtureRepo: Decodable {
    let id: String
    let path: String
    let pairedSpec: String?
    let expected: FixtureCounts
}

private struct FixtureCounts: Decodable, Equatable {
    let layers: Int
    let nodes: Int
    let edges: Int
    let entryPoints: Int
    let flows: Int
}

private struct ValidationExpectation: Decodable {
    let fatalCodes: [String]
    let warningCodes: [String]
}

private struct BenchmarkReport: Codable {
    let generatedAt: String
    let benchmarks: [BenchmarkRecord]
}

private struct BenchmarkRecord: Codable {
    let id: String
    let iterations: Int
    let averageMilliseconds: Double
}

private struct HarnessError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
