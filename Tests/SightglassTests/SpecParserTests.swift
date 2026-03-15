import Testing
@testable import SightglassCore

struct SpecParserTests {
    @Test func canonicalValidFixturesMatchManifestCounts() throws {
        let manifest = try FixtureLoader.manifest()
        let validFixtures = manifest.specs.filter { ($0.validation?.fatalCodes ?? []).isEmpty }

        for fixture in validFixtures {
            let yaml = try FixtureLoader.loadString(at: fixture.path)
            let spec = try SpecParser.parse(yamlString: yaml)

            #expect(spec.version == 2)
            #expect(spec.layers.count == fixture.expected.layers)
            #expect(spec.nodes.count == fixture.expected.nodes)
            #expect(spec.edges.count == fixture.expected.edges)
            #expect((spec.entryPoints?.count ?? 0) == fixture.expected.entryPoints)
            #expect((spec.flows?.count ?? 0) == fixture.expected.flows)

            let repositoryRoot = fixture.repo.map(FixtureLoader.repoURL)
            let validation = SpecParser.validate(spec, repositoryRoot: repositoryRoot)
            if !validation.isValid {
                Issue.record("\(fixture.id): \(validation.summary)")
            }
            #expect(validation.isValid)
            #expect(
                validation.warnings.map(\.code).sorted() ==
                    (fixture.validation?.warningCodes.sorted() ?? [])
            )
        }
    }

    @Test func v1SpecsMigrateToNormalizedV2Shape() throws {
        let yaml = """
        name: migrated-v1
        version: 1
        analyzed_at: 2026-03-15T14:00:00Z
        layers:
          - id: api
            name: API
            color: "#4A90D9"
          - id: data
            name: Data
            color: "#50C878"
        nodes:
          - id: route
            name: Route
            layer: api
            file: src/route.ts
          - id: repo
            name: Repo
            layer: data
            file: src/repo.ts
        edges:
          - from: route
            to: repo
            label: fetch
        """

        let spec = try SpecParser.parse(yamlString: yaml)

        #expect(spec.version == 2)
        #expect(spec.layers.map(\.rank) == [0, 1])
        #expect(spec.commitSHA == nil)
        #expect(spec.metadata == nil)
        #expect(spec.flows == nil)
        #expect(spec.types == nil)
    }

    @Test func invalidFixturesReportExpectedValidationCodes() throws {
        let manifest = try FixtureLoader.manifest()
        let invalidFixtures = manifest.specs.filter {
            !($0.validation?.fatalCodes.isEmpty ?? true) || !($0.validation?.warningCodes.isEmpty ?? true)
        }

        for fixture in invalidFixtures {
            let yaml = try FixtureLoader.loadString(at: fixture.path)
            let spec = try SpecParser.parse(yamlString: yaml)
            let repositoryRoot = fixture.repo.map(FixtureLoader.repoURL)
            let validation = SpecParser.validate(spec, repositoryRoot: repositoryRoot)

            #expect(validation.fatalErrors.map(\.code).sorted() == (fixture.validation?.fatalCodes.sorted() ?? []))
            #expect(validation.warnings.map(\.code).sorted() == (fixture.validation?.warningCodes.sorted() ?? []))
            #expect(!validation.remediationHints.isEmpty)
        }
    }

    @Test func eventDrivenFixturePreservesOptionalV2Fields() throws {
        let yaml = try FixtureLoader.loadString(at: "Specs/event-driven-service.yaml")
        let spec = try SpecParser.parse(yamlString: yaml)

        #expect(spec.metadata?.framework == "FastAPI + Celery")
        #expect(spec.commitSHA == "9f8e7d6")
        #expect(spec.nodes.first(where: { $0.id == "event-consumer" })?.technology == "Kafka Consumer")
        #expect(spec.nodes.first(where: { $0.id == "notification-router" })?.owner == "messaging-platform")
        #expect(spec.nodes.first(where: { $0.id == "push-sender" })?.lifecycle == "experimental")
        #expect(spec.edges.first(where: { $0.from == "event-consumer" })?.protocolName == "kafka")
        #expect(spec.entryPoints?.first?.requestType == "NotificationEvent")
        #expect(spec.types?.count == 2)
    }

    @Test func warningsStaySeparateFromFatalErrors() throws {
        let yaml = try FixtureLoader.loadString(at: "Specs/nonexistent-file-warning.yaml")
        let spec = try SpecParser.parse(yamlString: yaml)
        let validation = SpecParser.validate(
            spec,
            repositoryRoot: FixtureLoader.repoURL("Repos/express-api")
        )

        #expect(validation.fatalErrors.isEmpty)
        #expect(validation.warnings.map(\.code) == ["missing_node_file"])
        #expect(!validation.remediationHints.isEmpty)
    }
}
