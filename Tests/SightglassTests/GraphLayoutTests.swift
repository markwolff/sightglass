import Foundation
import Testing
@testable import SightglassCore

struct GraphLayoutTests {
    private func makeSpec(
        nodeCount: Int = 3,
        layerCount: Int = 2,
        edges: [(from: Int, to: Int)] = [(0, 1), (1, 2)]
    ) -> CodeSpec {
        let layers = (0..<layerCount).map { i in
            SpecLayer(id: "layer-\(i)", name: "Layer \(i)", color: "#AAAAAA", rank: i)
        }

        let nodes = (0..<nodeCount).map { i in
            SpecNode(
                id: "node-\(i)",
                name: "Node \(i)",
                layer: "layer-\(i % layerCount)",
                file: nil,
                description: nil,
                technology: nil,
                owner: nil,
                lifecycle: nil,
                types: nil,
                methods: nil
            )
        }

        let specEdges = edges.map { (from, to) in
            SpecEdge(
                from: "node-\(from)",
                to: "node-\(to)",
                label: "flow",
                dataType: nil,
                type: "calls",
                async: nil,
                protocolName: "function"
            )
        }

        return CodeSpec(
            name: "test",
            version: 2,
            analyzedAt: nil,
            commitSHA: nil,
            metadata: nil,
            layers: layers,
            nodes: nodes,
            edges: specEdges,
            entryPoints: nil,
            flows: nil,
            types: nil
        )
    }

    @Test func allNodesGetPositions() {
        let spec = makeSpec(nodeCount: 5)
        let layout = GraphLayout(spec: spec)
        let positions = layout.computePositions()

        #expect(positions.count == 5)
        for i in 0..<5 {
            #expect(positions["node-\(i)"] != nil)
        }
    }

    @Test func emptySpecProducesNoPositions() {
        let spec = CodeSpec(
            name: "empty",
            version: 2,
            analyzedAt: nil,
            commitSHA: nil,
            metadata: nil,
            layers: [],
            nodes: [],
            edges: [],
            entryPoints: nil,
            flows: nil,
            types: nil
        )
        let layout = GraphLayout(spec: spec)
        let positions = layout.computePositions()
        #expect(positions.isEmpty)
    }

    @Test func layersAreVerticallyOrderedByRank() throws {
        let spec = CodeSpec(
            name: "ranked",
            version: 2,
            analyzedAt: nil,
            commitSHA: nil,
            metadata: nil,
            layers: [
                SpecLayer(id: "low", name: "Low", color: "#FFAA00", rank: 2),
                SpecLayer(id: "top", name: "Top", color: "#00AAFF", rank: 0),
                SpecLayer(id: "mid", name: "Mid", color: "#33CC66", rank: 1),
            ],
            nodes: [
                SpecNode(id: "n1", name: "N1", layer: "top", file: nil, description: nil, technology: nil, owner: nil, lifecycle: nil, types: nil, methods: nil),
                SpecNode(id: "n2", name: "N2", layer: "mid", file: nil, description: nil, technology: nil, owner: nil, lifecycle: nil, types: nil, methods: nil),
                SpecNode(id: "n3", name: "N3", layer: "low", file: nil, description: nil, technology: nil, owner: nil, lifecycle: nil, types: nil, methods: nil),
            ],
            edges: [],
            entryPoints: nil,
            flows: nil,
            types: nil
        )

        let layout = GraphLayout(spec: spec)
        let positions = layout.computePositions()

        let n1 = try #require(positions["n1"])
        let n2 = try #require(positions["n2"])
        let n3 = try #require(positions["n3"])
        #expect(n1.y < n2.y)
        #expect(n2.y < n3.y)
    }

    @Test func nodesDoNotOverlap() {
        let spec = makeSpec(nodeCount: 5)
        let layout = GraphLayout(spec: spec)
        let positions = layout.computePositions()

        let nodeSize = CGSize(width: 160, height: 60)
        let posArray = Array(positions.values)

        for i in 0..<posArray.count {
            for j in (i + 1)..<posArray.count {
                let dx = abs(posArray[i].x - posArray[j].x)
                let dy = abs(posArray[i].y - posArray[j].y)

                let separated = dx > nodeSize.width * 0.5 || dy > nodeSize.height * 0.5
                #expect(separated)
            }
        }
    }

    @Test func connectedNodesStayCloserThanDisconnectedOnes() throws {
        let spec = makeSpec(
            nodeCount: 4,
            layerCount: 1,
            edges: [(0, 1)]
        )

        var layout = GraphLayout(spec: spec)
        layout.config.iterations = 200
        let positions = layout.computePositions()

        let pos0 = try #require(positions["node-0"])
        let pos1 = try #require(positions["node-1"])
        let pos3 = try #require(positions["node-3"])

        let connectedDist = hypot(pos0.x - pos1.x, pos0.y - pos1.y)
        let disconnectedDist = hypot(pos0.x - pos3.x, pos0.y - pos3.y)

        #expect(connectedDist < disconnectedDist * 2)
    }

    @Test func singleNodeProducesFinitePosition() throws {
        let spec = makeSpec(nodeCount: 1, layerCount: 1, edges: [])
        let layout = GraphLayout(spec: spec)
        let positions = layout.computePositions()

        #expect(positions.count == 1)
        let pos = try #require(positions["node-0"])
        #expect(!pos.x.isNaN)
        #expect(!pos.y.isNaN)
    }

    @Test func disconnectedNoiseDoesNotCollapseIntoMainPath() {
        let spec = makeSpec(
            nodeCount: 5,
            layerCount: 1,
            edges: [(0, 1), (1, 2)]
        )

        var layout = GraphLayout(spec: spec)
        layout.config.iterations = 200
        let positions = layout.computePositions()

        let clusterCenter = CGPoint(
            x: (positions["node-0"]!.x + positions["node-1"]!.x + positions["node-2"]!.x) / 3,
            y: (positions["node-0"]!.y + positions["node-1"]!.y + positions["node-2"]!.y) / 3
        )

        let disconnected = positions["node-4"]!
        let distance = hypot(disconnected.x - clusterCenter.x, disconnected.y - clusterCenter.y)
        #expect(distance > 120)
    }

    @Test func geometrySnapshotsStayStableForCanonicalFixtures() throws {
        let manifest = try FixtureLoader.manifest()
        let snapshotFixtures = manifest.specs.filter { $0.snapshot != nil }

        for fixture in snapshotFixtures {
            let yaml = try FixtureLoader.loadString(at: fixture.path)
            let spec = try SpecParser.parse(yamlString: yaml)
            let positions = GraphLayout(spec: spec).computePositions()
            let snapshot = DiagramGeometrySnapshotBuilder.makeSnapshot(spec: spec, positions: positions)
            let data = try makeSnapshotJSON(for: snapshot)
            let snapshotPath = fixture.snapshot!

            if ProcessInfo.processInfo.environment["SIGHTGLASS_UPDATE_SNAPSHOTS"] == "1" {
                try data.write(to: FixtureLoader.fixtureURL(snapshotPath), options: .atomic)
            }

            let expectedData = try Data(contentsOf: FixtureLoader.fixtureURL(snapshotPath))
            #expect(String(decoding: data, as: UTF8.self) == String(decoding: expectedData, as: UTF8.self))
        }
    }

    private func makeSnapshotJSON(for snapshot: DiagramGeometrySnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }
}
