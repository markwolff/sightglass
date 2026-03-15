import Foundation

/// Computes node positions for the graph using a force-directed layout algorithm.
///
/// The algorithm treats nodes as charged particles that repel each other
/// and edges as springs that pull connected nodes together. Nodes are also
/// attracted to their layer's horizontal band for a loosely hierarchical layout.
struct GraphLayout {
    let spec: CodeSpec

    /// Configuration for the force-directed simulation
    struct Config {
        /// Repulsion force between all nodes
        var repulsionStrength: CGFloat = 5000

        /// Spring force along edges
        var springStrength: CGFloat = 0.05

        /// Ideal edge length
        var idealEdgeLength: CGFloat = 200

        /// Force pulling nodes toward their layer band
        var layerGravity: CGFloat = 0.1

        /// Damping factor to slow movement over iterations
        var damping: CGFloat = 0.85

        /// Number of simulation iterations
        var iterations: Int = 100

        /// Vertical spacing between layer bands
        var layerSpacing: CGFloat = 200

        /// Horizontal spacing base for initial positions
        var horizontalSpacing: CGFloat = 250
    }

    var config = Config()

    /// Computes positions for all nodes in the graph.
    ///
    /// Returns a dictionary mapping node ID to its computed position.
    func computePositions() -> [String: CGPoint] {
        guard !spec.nodes.isEmpty else { return [:] }

        // Initialize positions using a layer-based heuristic
        var positions = initialPositions()
        var velocities: [String: CGPoint] = [:]
        for node in spec.nodes {
            velocities[node.id] = .zero
        }

        // Run force-directed simulation
        for _ in 0..<config.iterations {
            var forces: [String: CGPoint] = [:]
            for node in spec.nodes {
                forces[node.id] = .zero
            }

            // Repulsion between all pairs of nodes
            applyRepulsionForces(positions: positions, forces: &forces)

            // Spring forces along edges
            applySpringForces(positions: positions, forces: &forces)

            // Layer gravity (attract nodes to their layer band)
            applyLayerGravity(positions: positions, forces: &forces)

            // Update positions using forces and velocities
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

        // Center the layout
        return centerPositions(positions)
    }

    // MARK: - Initial Positions

    /// Places nodes in a grid organized by layer.
    private func initialPositions() -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]

        // Group nodes by layer
        var nodesByLayer: [String: [SpecNode]] = [:]
        for node in spec.nodes {
            nodesByLayer[node.layer, default: []].append(node)
        }

        // Assign each layer a vertical band
        let layerOrder = spec.layers.map(\.id)

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

    // MARK: - Forces

    /// Applies Coulomb-like repulsion between all node pairs.
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

    /// Applies Hooke's law spring forces along edges.
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

    /// Applies a gentle force pulling nodes toward their layer's vertical band.
    private func applyLayerGravity(positions: [String: CGPoint], forces: inout [String: CGPoint]) {
        let layerOrder = spec.layers.map(\.id)

        for node in spec.nodes {
            guard let layerIndex = layerOrder.firstIndex(of: node.layer),
                  let pos = positions[node.id] else { continue }

            let targetY = CGFloat(layerIndex) * config.layerSpacing + 100
            let dy = targetY - pos.y
            forces[node.id]?.y += dy * config.layerGravity
        }
    }

    // MARK: - Centering

    /// Centers all positions around a reasonable origin.
    private func centerPositions(_ positions: [String: CGPoint]) -> [String: CGPoint] {
        guard !positions.isEmpty else { return positions }

        let allX = positions.values.map(\.x)
        let allY = positions.values.map(\.y)

        let centerX = (allX.min()! + allX.max()!) / 2
        let centerY = (allY.min()! + allY.max()!) / 2

        let targetCenter = CGPoint(x: 500, y: 400) // Reasonable default center

        var centered: [String: CGPoint] = [:]
        for (id, pos) in positions {
            centered[id] = CGPoint(
                x: pos.x - centerX + targetCenter.x,
                y: pos.y - centerY + targetCenter.y
            )
        }

        return centered
    }
}
