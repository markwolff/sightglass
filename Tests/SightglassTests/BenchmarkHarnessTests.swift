import Foundation
import Testing
@testable import SightglassCore

struct BenchmarkHarnessTests {
    @Test func benchmarkHarnessExportsMachineReadableResults() throws {
        let manifest = try FixtureLoader.manifest()
        let benchmarkFixtureIDs = ["minimal-valid", "layered-rest-service", "large-graph"]

        let benchmarks = try benchmarkFixtureIDs.flatMap { fixtureID in
            let fixture = try #require(manifest.specs.first(where: { $0.id == fixtureID }))
            return try benchmarkRecords(for: fixture)
        }

        #expect(!benchmarks.isEmpty)
        #expect(benchmarks.allSatisfy { $0.averageMilliseconds > 0 })

        if let outputPath = ProcessInfo.processInfo.environment["SIGHTGLASS_BENCHMARK_OUTPUT"] {
            let report = BenchmarkReport(
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                benchmarks: benchmarks
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        }
    }

    private func benchmarkRecords(for fixture: SpecFixture) throws -> [BenchmarkRecord] {
        let yaml = try FixtureLoader.loadString(at: fixture.path)
        let repositoryRoot = fixture.repo.map(FixtureLoader.repoURL)
        let parsedSpec = try SpecParser.parse(yamlString: yaml)
        let positions = GraphLayout(spec: parsedSpec).computePositions()

        return [
            BenchmarkRecord(
                id: "\(fixture.id).parse",
                iterations: 25,
                averageMilliseconds: try benchmark(iterations: 25) {
                    _ = try SpecParser.parse(yamlString: yaml)
                }
            ),
            BenchmarkRecord(
                id: "\(fixture.id).validate",
                iterations: 50,
                averageMilliseconds: benchmark(iterations: 50) {
                    _ = SpecParser.validate(parsedSpec, repositoryRoot: repositoryRoot)
                }
            ),
            BenchmarkRecord(
                id: "\(fixture.id).layout",
                iterations: 15,
                averageMilliseconds: benchmark(iterations: 15) {
                    _ = GraphLayout(spec: parsedSpec).computePositions()
                }
            ),
            BenchmarkRecord(
                id: "\(fixture.id).render",
                iterations: 50,
                averageMilliseconds: benchmark(iterations: 50) {
                    _ = DiagramGeometrySnapshotBuilder.makeSnapshot(spec: parsedSpec, positions: positions)
                }
            ),
        ]
    }

    private func benchmark(iterations: Int, work: () throws -> Void) rethrows -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            try work()
        }
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return elapsedMilliseconds / Double(iterations)
    }
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
