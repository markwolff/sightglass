import Foundation

/// Computes node positions for the graph using either a hybrid Sugiyama layered
/// layout or a force-directed layout algorithm.
public struct GraphLayout {
    public let spec: CodeSpec

    public enum Algorithm {
        case hybridLayered
        case forceDirected
    }

    /// Configuration for the layout simulation
    public struct Config {
        /// Repulsion force between all nodes (force-directed)
        public var repulsionStrength: CGFloat = 5000

        /// Spring force along edges (force-directed)
        public var springStrength: CGFloat = 0.05

        /// Ideal edge length
        public var idealEdgeLength: CGFloat = 200

        /// Force pulling nodes toward their layer band (force-directed)
        public var layerGravity: CGFloat = 0.1

        /// Damping factor to slow movement over iterations (force-directed)
        public var damping: CGFloat = 0.85

        /// Number of simulation iterations (force-directed)
        public var iterations: Int = 100

        /// Vertical spacing between layer bands
        public var layerSpacing: CGFloat = 200

        /// Horizontal spacing base for initial positions
        public var horizontalSpacing: CGFloat = 250

        /// Number of barycenter sweeps for crossing reduction (Sugiyama)
        public var sugiyamaSweeps: Int = 8

        /// Number of edge straightening iterations (Sugiyama)
        public var edgeStraighteningIterations: Int = 10

        /// Strength of edge straightening force (Sugiyama)
        public var edgeStraighteningStrength: CGFloat = 0.3

        public init() {}
    }

    public var config = Config()
    public var algorithm: Algorithm = .hybridLayered

    public init(spec: CodeSpec) {
        self.spec = spec
    }

    /// Computes positions for all nodes in the graph.
    public func computePositions() -> [String: CGPoint] {
        guard !spec.nodes.isEmpty else { return [:] }

        switch algorithm {
        case .hybridLayered:
            return computeHybridLayeredPositions()
        case .forceDirected:
            return computeForceDirectedPositions()
        }
    }

    // MARK: - Hybrid Sugiyama Layout

    private func computeHybridLayeredPositions() -> [String: CGPoint] {
        let layers = orderedLayers()
        let layerOrder = layers.map(\.id)

        // Step 1: Group nodes by layer
        var nodesByLayer: [String: [SpecNode]] = [:]
        for node in spec.nodes {
            nodesByLayer[node.layer, default: []].append(node)
        }

        // Build adjacency for crossing reduction
        let adjacency = buildAdjacency()

        // Step 2: Crossing reduction via barycenter heuristic
        var orderedNodesByLayer: [[String]] = layerOrder.map { layerID in
            (nodesByLayer[layerID] ?? []).map(\.id)
        }

        for sweep in 0..<config.sugiyamaSweeps {
            if sweep % 2 == 0 {
                // Top-down sweep
                for layerIdx in 1..<orderedNodesByLayer.count {
                    orderedNodesByLayer[layerIdx] = reorderByBarycenter(
                        layer: orderedNodesByLayer[layerIdx],
                        referenceLayer: orderedNodesByLayer[layerIdx - 1],
                        adjacency: adjacency
                    )
                }
            } else {
                // Bottom-up sweep
                for layerIdx in stride(from: orderedNodesByLayer.count - 2, through: 0, by: -1) {
                    orderedNodesByLayer[layerIdx] = reorderByBarycenter(
                        layer: orderedNodesByLayer[layerIdx],
                        referenceLayer: orderedNodesByLayer[layerIdx + 1],
                        adjacency: adjacency
                    )
                }
            }
        }

        // Step 3: X-coordinate assignment
        var positions: [String: CGPoint] = [:]
        for (layerIdx, nodeIDs) in orderedNodesByLayer.enumerated() {
            let y = CGFloat(layerIdx) * config.layerSpacing + 100
            let totalWidth = CGFloat(nodeIDs.count - 1) * config.horizontalSpacing
            let startX = -totalWidth / 2

            for (nodeIdx, nodeID) in nodeIDs.enumerated() {
                let x = startX + CGFloat(nodeIdx) * config.horizontalSpacing
                positions[nodeID] = CGPoint(x: x, y: y)
            }
        }

        // Step 4: Edge straightening (horizontal-only forces)
        positions = straightenEdges(positions)

        // Step 5: Overlap resolution
        let resolvedPositions = resolveOverlaps(positions)

        // Step 6: Centering
        return centerPositions(resolvedPositions)
    }

    private func buildAdjacency() -> [String: Set<String>] {
        var adjacency: [String: Set<String>] = [:]
        for node in spec.nodes {
            adjacency[node.id] = []
        }
        for edge in spec.edges {
            adjacency[edge.from, default: []].insert(edge.to)
            adjacency[edge.to, default: []].insert(edge.from)
        }
        return adjacency
    }

    private func reorderByBarycenter(
        layer: [String],
        referenceLayer: [String],
        adjacency: [String: Set<String>]
    ) -> [String] {
        let referencePositions: [String: Int] = Dictionary(
            uniqueKeysWithValues: referenceLayer.enumerated().map { ($1, $0) }
        )

        var barycenters: [(id: String, value: Double)] = []

        for nodeID in layer {
            let neighbors = adjacency[nodeID] ?? []
            let referenceNeighbors = neighbors.compactMap { referencePositions[$0] }

            if referenceNeighbors.isEmpty {
                // Keep original relative position
                let originalIndex = layer.firstIndex(of: nodeID) ?? 0
                barycenters.append((nodeID, Double(originalIndex)))
            } else {
                let avg = Double(referenceNeighbors.reduce(0, +)) / Double(referenceNeighbors.count)
                barycenters.append((nodeID, avg))
            }
        }

        barycenters.sort { $0.value < $1.value }
        return barycenters.map(\.id)
    }

    private func straightenEdges(_ positions: [String: CGPoint]) -> [String: CGPoint] {
        var adjusted = positions
        let minimumSpacing: CGFloat = 170

        for _ in 0..<config.edgeStraighteningIterations {
            var forces: [String: CGFloat] = [:]
            for node in spec.nodes {
                forces[node.id] = 0
            }

            // Apply horizontal attraction toward connected nodes
            for edge in spec.edges {
                guard let fromPos = adjusted[edge.from],
                      let toPos = adjusted[edge.to] else { continue }

                let dx = toPos.x - fromPos.x
                let force = dx * config.edgeStraighteningStrength

                forces[edge.from]? += force
                forces[edge.to]? -= force
            }

            // Apply forces (horizontal only)
            for node in spec.nodes {
                guard let force = forces[node.id],
                      var pos = adjusted[node.id] else { continue }
                pos.x += force
                adjusted[node.id] = pos
            }

            // Enforce minimum spacing within each layer
            let layerOrder = orderedLayers().map(\.id)
            var nodesByLayer: [String: [String]] = [:]
            for node in spec.nodes {
                nodesByLayer[node.layer, default: []].append(node.id)
            }

            for layerID in layerOrder {
                guard var layerNodes = nodesByLayer[layerID] else { continue }
                layerNodes.sort { (adjusted[$0]?.x ?? 0) < (adjusted[$1]?.x ?? 0) }

                for i in 1..<layerNodes.count {
                    guard let prevPos = adjusted[layerNodes[i - 1]],
                          var currPos = adjusted[layerNodes[i]] else { continue }
                    let gap = currPos.x - prevPos.x
                    if gap < minimumSpacing {
                        currPos.x = prevPos.x + minimumSpacing
                        adjusted[layerNodes[i]] = currPos
                    }
                }
            }
        }

        return adjusted
    }

    // MARK: - Force-Directed Layout

    private func computeForceDirectedPositions() -> [String: CGPoint] {
        var positions = initialPositions()
        var velocities: [String: CGPoint] = [:]
        for node in spec.nodes {
            velocities[node.id] = .zero
        }

        for _ in 0..<config.iterations {
            var forces: [String: CGPoint] = [:]
            for node in spec.nodes {
                forces[node.id] = .zero
            }

            applyRepulsionForces(positions: positions, forces: &forces)
            applySpringForces(positions: positions, forces: &forces)
            applyLayerGravity(positions: positions, forces: &forces)

            for node in spec.nodes {
                guard var vel = velocities[node.id],
                      let force = forces[node.id],
                      var pos = positions[node.id] else { continue }

                vel.x = (vel.x + force.x) * config.damping
                vel.y = (vel.y + force.y) * config.damping

                pos.x += vel.x
                pos.y += vel.y

                velocities[node.id] = vel
                positions[node.id] = pos
            }
        }

        let resolvedPositions = resolveOverlaps(positions)
        return centerPositions(resolvedPositions)
    }

    // MARK: - Initial Positions (Force-Directed)

    private func initialPositions() -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]

        var nodesByLayer: [String: [SpecNode]] = [:]
        for node in spec.nodes {
            nodesByLayer[node.layer, default: []].append(node)
        }

        let layerOrder = orderedLayers().map(\.id)

        for (layerIndex, layerID) in layerOrder.enumerated() {
            let layerNodes = nodesByLayer[layerID] ?? []
            let y = CGFloat(layerIndex) * config.layerSpacing + 100

            for (nodeIndex, node) in layerNodes.enumerated() {
                let x = CGFloat(nodeIndex) * config.horizontalSpacing + 100
                positions[node.id] = CGPoint(x: x, y: y)
            }
        }

        return positions
    }

    // MARK: - Forces (Force-Directed)

    private func applyRepulsionForces(positions: [String: CGPoint], forces: inout [String: CGPoint]) {
        let nodes = spec.nodes
        for i in 0..<nodes.count {
            for j in (i + 1)..<nodes.count {
                guard let posI = positions[nodes[i].id],
                      let posJ = positions[nodes[j].id] else { continue }

                let dx = posI.x - posJ.x
                let dy = posI.y - posJ.y
                let distSq = max(dx * dx + dy * dy, 1)
                let dist = sqrt(distSq)

                let force = config.repulsionStrength / distSq
                let fx = force * dx / dist
                let fy = force * dy / dist

                forces[nodes[i].id]?.x += fx
                forces[nodes[i].id]?.y += fy
                forces[nodes[j].id]?.x -= fx
                forces[nodes[j].id]?.y -= fy
            }
        }
    }

    private func applySpringForces(positions: [String: CGPoint], forces: inout [String: CGPoint]) {
        for edge in spec.edges {
            guard let posFrom = positions[edge.from],
                  let posTo = positions[edge.to] else { continue }

            let dx = posTo.x - posFrom.x
            let dy = posTo.y - posFrom.y
            let dist = max(sqrt(dx * dx + dy * dy), 1)
            let displacement = dist - config.idealEdgeLength

            let force = config.springStrength * displacement
            let fx = force * dx / dist
            let fy = force * dy / dist

            forces[edge.from]?.x += fx
            forces[edge.from]?.y += fy
            forces[edge.to]?.x -= fx
            forces[edge.to]?.y -= fy
        }
    }

    private func applyLayerGravity(positions: [String: CGPoint], forces: inout [String: CGPoint]) {
        let layerOrder = orderedLayers().map(\.id)

        for node in spec.nodes {
            guard let layerIndex = layerOrder.firstIndex(of: node.layer),
                  let pos = positions[node.id] else { continue }

            let targetY = CGFloat(layerIndex) * config.layerSpacing + 100
            let dy = targetY - pos.y
            forces[node.id]?.y += dy * config.layerGravity
        }
    }

    // MARK: - Shared Utilities

    private func centerPositions(_ positions: [String: CGPoint]) -> [String: CGPoint] {
        guard !positions.isEmpty else { return positions }

        let allX = positions.values.map(\.x)
        let allY = positions.values.map(\.y)

        let centerX = (allX.min()! + allX.max()!) / 2
        let centerY = (allY.min()! + allY.max()!) / 2

        let targetCenter = CGPoint(x: 500, y: 400)

        var centered: [String: CGPoint] = [:]
        for (id, pos) in positions {
            centered[id] = CGPoint(
                x: pos.x - centerX + targetCenter.x,
                y: pos.y - centerY + targetCenter.y
            )
        }

        return centered
    }

    private func resolveOverlaps(_ positions: [String: CGPoint]) -> [String: CGPoint] {
        var adjusted = positions
        let minimumHorizontalSpacing: CGFloat = 170
        let minimumVerticalSpacing: CGFloat = 70

        for _ in 0..<12 {
            var moved = false

            for i in 0..<spec.nodes.count {
                for j in (i + 1)..<spec.nodes.count {
                    let leftNode = spec.nodes[i]
                    let rightNode = spec.nodes[j]

                    guard var leftPosition = adjusted[leftNode.id],
                          var rightPosition = adjusted[rightNode.id] else {
                        continue
                    }

                    let dx = rightPosition.x - leftPosition.x
                    let dy = rightPosition.y - leftPosition.y

                    guard abs(dx) < minimumHorizontalSpacing,
                          abs(dy) < minimumVerticalSpacing else {
                        continue
                    }

                    let horizontalPush = (minimumHorizontalSpacing - abs(dx)) / 2 + 8

                    if dx >= 0 {
                        leftPosition.x -= horizontalPush
                        rightPosition.x += horizontalPush
                    } else {
                        leftPosition.x += horizontalPush
                        rightPosition.x -= horizontalPush
                    }

                    adjusted[leftNode.id] = leftPosition
                    adjusted[rightNode.id] = rightPosition
                    moved = true
                }
            }

            if !moved {
                break
            }
        }

        return adjusted
    }

    private func orderedLayers() -> [SpecLayer] {
        spec.layers.sorted { lhs, rhs in
            if lhs.rank == rhs.rank {
                return lhs.id < rhs.id
            }
            return lhs.rank < rhs.rank
        }
    }
}
