import SwiftUI

/// Renders the code architecture graph on a SwiftUI Canvas.
///
/// Draws nodes as rounded rectangles color-coded by layer,
/// edges as lines/curves with labels, and highlights the selected node.
struct DiagramRenderer {
    let spec: CodeSpec
    let nodePositions: [String: CGPoint]
    let selectedNodeID: String?
    let zoom: CGFloat
    let panOffset: CGSize
    let canvasSize: CGSize

    /// Standard node dimensions
    private let nodeWidth: CGFloat = 160
    private let nodeHeight: CGFloat = 60
    private let nodeCornerRadius: CGFloat = 10

    /// Renders the entire diagram into the given graphics context.
    func render(in context: inout GraphicsContext) {
        // Apply global transform (pan + zoom)
        context.translateBy(x: panOffset.width, y: panOffset.height)
        context.scaleBy(x: zoom, y: zoom)

        // Draw layer backgrounds
        drawLayerBackgrounds(in: &context)

        // Draw edges first (behind nodes)
        for edge in spec.edges {
            drawEdge(edge, in: &context)
        }

        // Draw nodes on top
        for node in spec.nodes {
            drawNode(node, in: &context)
        }

        // Draw entry point indicators
        if let entryPoints = spec.entryPoints {
            for entryPoint in entryPoints {
                drawEntryPoint(entryPoint, in: &context)
            }
        }
    }

    // MARK: - Layer Backgrounds

    private func drawLayerBackgrounds(in context: inout GraphicsContext) {
        // TODO: Draw semi-transparent backgrounds for each layer region
        // Group nodes by layer, compute bounding box, draw background
    }

    // MARK: - Edge Drawing

    private func drawEdge(_ edge: SpecEdge, in context: inout GraphicsContext) {
        guard let fromPos = nodePositions[edge.from],
              let toPos = nodePositions[edge.to] else { return }

        var path = Path()
        path.move(to: fromPos)
        path.addLine(to: toPos)

        // Draw the line
        let strokeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round)
        context.stroke(path, with: .color(.secondary.opacity(0.6)), style: strokeStyle)

        // Draw arrowhead
        drawArrowhead(from: fromPos, to: toPos, in: &context)

        // Draw label at midpoint
        if let label = edge.label {
            let midpoint = CGPoint(
                x: (fromPos.x + toPos.x) / 2,
                y: (fromPos.y + toPos.y) / 2 - 12
            )
            let text = Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            context.draw(context.resolve(text), at: midpoint)
        }
    }

    private func drawArrowhead(from: CGPoint, to: CGPoint, in context: inout GraphicsContext) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowLength: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6

        // Stop the arrow at the edge of the target node
        let targetPoint = CGPoint(
            x: to.x - cos(angle) * nodeWidth / 2,
            y: to.y - sin(angle) * nodeHeight / 2
        )

        var path = Path()
        path.move(to: targetPoint)
        path.addLine(to: CGPoint(
            x: targetPoint.x - arrowLength * cos(angle - arrowAngle),
            y: targetPoint.y - arrowLength * sin(angle - arrowAngle)
        ))
        path.move(to: targetPoint)
        path.addLine(to: CGPoint(
            x: targetPoint.x - arrowLength * cos(angle + arrowAngle),
            y: targetPoint.y - arrowLength * sin(angle + arrowAngle)
        ))

        context.stroke(path, with: .color(.secondary.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    // MARK: - Node Drawing

    private func drawNode(_ node: SpecNode, in context: inout GraphicsContext) {
        guard let position = nodePositions[node.id] else { return }

        let rect = CGRect(
            x: position.x - nodeWidth / 2,
            y: position.y - nodeHeight / 2,
            width: nodeWidth,
            height: nodeHeight
        )

        let roundedRect = RoundedRectangle(cornerRadius: nodeCornerRadius)
        let path = roundedRect.path(in: rect)

        // Determine color from layer
        let layerColor = colorForLayer(node.layer)

        // Fill
        let isSelected = node.id == selectedNodeID
        let fillColor = isSelected ? layerColor.opacity(0.3) : layerColor.opacity(0.15)
        context.fill(path, with: .color(fillColor))

        // Stroke
        let strokeColor = isSelected ? layerColor : layerColor.opacity(0.5)
        let lineWidth: CGFloat = isSelected ? 2.5 : 1.5
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: lineWidth))

        // Node name
        let nameText = Text(node.name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primary)
        context.draw(context.resolve(nameText), at: CGPoint(x: position.x, y: position.y - 8))

        // Layer badge
        if let layer = spec.layers.first(where: { $0.id == node.layer }) {
            let badgeText = Text(layer.name)
                .font(.system(size: 9))
                .foregroundColor(layerColor)
            context.draw(context.resolve(badgeText), at: CGPoint(x: position.x, y: position.y + 12))
        }
    }

    // MARK: - Entry Point Drawing

    private func drawEntryPoint(_ entryPoint: EntryPoint, in context: inout GraphicsContext) {
        guard let nodePos = nodePositions[entryPoint.node] else { return }

        // TODO: Draw an indicator (e.g., small arrow or icon) pointing to the node
        // For now, draw a small diamond to the left of the node
        let indicatorPos = CGPoint(x: nodePos.x - nodeWidth / 2 - 20, y: nodePos.y)

        var path = Path()
        path.move(to: CGPoint(x: indicatorPos.x, y: indicatorPos.y - 6))
        path.addLine(to: CGPoint(x: indicatorPos.x + 6, y: indicatorPos.y))
        path.addLine(to: CGPoint(x: indicatorPos.x, y: indicatorPos.y + 6))
        path.addLine(to: CGPoint(x: indicatorPos.x - 6, y: indicatorPos.y))
        path.closeSubpath()

        context.fill(path, with: .color(.orange.opacity(0.8)))
    }

    // MARK: - Helpers

    private func colorForLayer(_ layerID: String) -> Color {
        spec.layers.first(where: { $0.id == layerID })?.swiftUIColor ?? .gray
    }
}
