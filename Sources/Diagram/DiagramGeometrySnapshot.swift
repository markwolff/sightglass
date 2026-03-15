import Foundation
import CoreGraphics

public struct DiagramGeometrySnapshot: Codable, Equatable {
    public let layers: [LayerBand]
    public let nodes: [NodeFrame]
    public let edges: [EdgeSegment]
    public let entryPoints: [EntryPointMarker]

    public struct LayerBand: Codable, Equatable {
        public let id: String
        public let name: String
        public let rank: Int
        public let minX: Double
        public let maxX: Double
        public let minY: Double
        public let maxY: Double
    }

    public struct NodeFrame: Codable, Equatable {
        public let id: String
        public let layer: String
        public let centerX: Double
        public let centerY: Double
        public let width: Double
        public let height: Double
    }

    public struct EdgeSegment: Codable, Equatable {
        public let id: String
        public let from: String
        public let to: String
        public let startX: Double
        public let startY: Double
        public let endX: Double
        public let endY: Double
    }

    public struct EntryPointMarker: Codable, Equatable {
        public let id: String
        public let node: String
        public let x: Double
        public let y: Double
    }
}

public enum DiagramGeometrySnapshotBuilder {
    public static func makeSnapshot(
        spec: CodeSpec,
        positions: [String: CGPoint],
        nodeSize: CGSize = CGSize(width: 160, height: 60),
        layerPadding: CGFloat = 80
    ) -> DiagramGeometrySnapshot {
        let orderedLayers = spec.layers.sorted { lhs, rhs in
            if lhs.rank == rhs.rank {
                return lhs.id < rhs.id
            }
            return lhs.rank < rhs.rank
        }

        let nodeFrames = spec.nodes
            .sorted { $0.id < $1.id }
            .compactMap { node -> DiagramGeometrySnapshot.NodeFrame? in
                guard let position = positions[node.id] else { return nil }
                return DiagramGeometrySnapshot.NodeFrame(
                    id: node.id,
                    layer: node.layer,
                    centerX: rounded(position.x),
                    centerY: rounded(position.y),
                    width: rounded(nodeSize.width),
                    height: rounded(nodeSize.height)
                )
            }

        let layerBands = orderedLayers.compactMap { layer -> DiagramGeometrySnapshot.LayerBand? in
            let frames = nodeFrames.filter { $0.layer == layer.id }
            guard !frames.isEmpty else { return nil }

            let minX = frames.map { CGFloat($0.centerX) - nodeSize.width / 2 }.min() ?? 0
            let maxX = frames.map { CGFloat($0.centerX) + nodeSize.width / 2 }.max() ?? 0
            let minY = frames.map { CGFloat($0.centerY) - nodeSize.height / 2 }.min() ?? 0
            let maxY = frames.map { CGFloat($0.centerY) + nodeSize.height / 2 }.max() ?? 0

            return DiagramGeometrySnapshot.LayerBand(
                id: layer.id,
                name: layer.name,
                rank: layer.rank,
                minX: rounded(minX - layerPadding),
                maxX: rounded(maxX + layerPadding),
                minY: rounded(minY - layerPadding / 2),
                maxY: rounded(maxY + layerPadding / 2)
            )
        }

        let edgeSegments = spec.edges
            .sorted { lhs, rhs in
                if lhs.from == rhs.from {
                    return lhs.to < rhs.to
                }
                return lhs.from < rhs.from
            }
            .compactMap { edge -> DiagramGeometrySnapshot.EdgeSegment? in
                guard let from = positions[edge.from], let to = positions[edge.to] else { return nil }
                return DiagramGeometrySnapshot.EdgeSegment(
                    id: edge.id,
                    from: edge.from,
                    to: edge.to,
                    startX: rounded(from.x),
                    startY: rounded(from.y),
                    endX: rounded(to.x),
                    endY: rounded(to.y)
                )
            }

        let entryPointMarkers = (spec.entryPoints ?? [])
            .sorted { $0.id < $1.id }
            .compactMap { entryPoint -> DiagramGeometrySnapshot.EntryPointMarker? in
                guard let nodePosition = positions[entryPoint.node] else { return nil }
                return DiagramGeometrySnapshot.EntryPointMarker(
                    id: entryPoint.id,
                    node: entryPoint.node,
                    x: rounded(nodePosition.x - nodeSize.width / 2 - 20),
                    y: rounded(nodePosition.y)
                )
            }

        return DiagramGeometrySnapshot(
            layers: layerBands,
            nodes: nodeFrames,
            edges: edgeSegments,
            entryPoints: entryPointMarkers
        )
    }

    private static func rounded(_ value: CGFloat) -> Double {
        Double((value * 100).rounded() / 100)
    }
}
