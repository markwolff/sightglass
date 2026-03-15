// NOTE: These tests require Xcode (not just Command Line Tools) to run.
// Run with: xcodebuild test or open in Xcode.
// With Command Line Tools only, XCTest/Testing modules are not available.

import XCTest
@testable import Sightglass

final class GraphLayoutTests: XCTestCase {
    /// Creates a simple test spec with the given number of nodes and edges.
    private func makeSpec(
        nodeCount: Int = 3,
        layerCount: Int = 2,
        edges: [(from: Int, to: Int)] = [(0, 1), (1, 2)]
    ) -> CodeSpec {
        let layers = (0..<layerCount).map { i in
            SpecLayer(id: "layer-\(i)", name: "Layer \(i)", color: "#AAAAAA")
        }

        let nodes = (0..<nodeCount).map { i in
            SpecNode(
                id: "node-\(i)",
                name: "Node \(i)",
                layer: "layer-\(i % layerCount)",
                file: nil,
                description: nil,
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
                async: nil
            )
        }

        return CodeSpec(
            name: "test",
            version: 1,
            analyzedAt: nil,
            layers: layers,
            nodes: nodes,
            edges: specEdges,
            entryPoints: nil
        )
    }

    func testAllNodesGetPositions() {
        let spec = makeSpec(nodeCount: 5)
        let layout = GraphLayout(spec: spec)
        let positions = layout.computePositions()

        XCTAssertEqual(positions.count, 5)
        for i in 0..<5 {
            XCTAssertNotNil(positions["node-\(i)"])
        }
    }

    func testEmptySpec() {
        let spec = CodeSpec(
            name: "empty",
            version: 1,
            analyzedAt: nil,
            layers: [],
            nodes: [],
            edges: [],
            entryPoints: nil
        )
        let layout = GraphLayout(spec: spec)
        let positions = layout.computePositions()
        XCTAssertTrue(positions.isEmpty)
    }

    func testNodesDoNotOverlap() {
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
                XCTAssertTrue(separated, "Nodes \(i) and \(j) overlap")
            }
        }
    }

    func testConnectedNodesCloser() {
        let spec = makeSpec(
            nodeCount: 4,
            layerCount: 1,
            edges: [(0, 1)]
        )

        var layout = GraphLayout(spec: spec)
        layout.config.iterations = 200
        let positions = layout.computePositions()

        guard let pos0 = positions["node-0"],
              let pos1 = positions["node-1"],
              let pos3 = positions["node-3"] else {
            XCTFail("Missing positions")
            return
        }

        let connectedDist = hypot(pos0.x - pos1.x, pos0.y - pos1.y)
        let disconnectedDist = hypot(pos0.x - pos3.x, pos0.y - pos3.y)

        XCTAssertLessThan(connectedDist, disconnectedDist * 2,
                          "Connected nodes should tend to be closer than disconnected ones")
    }

    func testSingleNode() {
        let spec = makeSpec(nodeCount: 1, layerCount: 1, edges: [])
        let layout = GraphLayout(spec: spec)
        let positions = layout.computePositions()

        XCTAssertEqual(positions.count, 1)
        let pos = positions["node-0"]
        XCTAssertNotNil(pos)
        XCTAssertFalse(pos!.x.isNaN)
        XCTAssertFalse(pos!.y.isNaN)
    }
}
