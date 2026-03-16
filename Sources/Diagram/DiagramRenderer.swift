import SwiftUI
import SightglassCore

/// Renders the code architecture graph on a SwiftUI Canvas.
///
/// Draws layer background cards, Bezier-routed edges with style variants,
/// nodes as rounded rectangles color-coded by layer, and entry point
/// indicators. Supports viewport culling and level-of-detail rendering.
struct DiagramRenderer {
    let spec: CodeSpec
    let nodePositions: [String: CGPoint]
    let selectedNodeID: String?
    let hoveredNodeID: String?
    let visibleLayerIDs: Set<String>
    let zoom: CGFloat
    let panOffset: CGSize
    let canvasSize: CGSize

    /// Standard node dimensions
    private let nodeWidth: CGFloat = 160
    private let nodeHeight: CGFloat = 60
    private let nodeCornerRadius: CGFloat = 10

    /// Padding around layer bounding boxes
    private let layerPadding: CGFloat = 80

    /// Extra padding added to the visible rect to avoid pop-in
    private let cullPadding: CGFloat = 200

    // MARK: - Visible Rect

    /// The rectangle visible on screen in canvas (world) coordinates.
    private var visibleRect: CGRect {
        let originX = -panOffset.width / zoom
        let originY = -panOffset.height / zoom
        let width = canvasSize.width / zoom
        let height = canvasSize.height / zoom
        return CGRect(
            x: originX - cullPadding,
            y: originY - cullPadding,
            width: width + cullPadding * 2,
            height: height + cullPadding * 2
        )
    }

    // MARK: - Level of Detail

    private enum DetailLevel {
        case minimal   // zoom < 0.3
        case reduced   // 0.3 <= zoom < 0.7
        case full      // zoom >= 0.7
    }

    private var detailLevel: DetailLevel {
        if zoom < 0.3 { return .minimal }
        if zoom < 0.7 { return .reduced }
        return .full
    }

    // MARK: - Main Render

    /// Renders the entire diagram into the given graphics context.
    func render(in context: inout GraphicsContext) {
        // Apply global transform (pan + zoom)
        context.translateBy(x: panOffset.width, y: panOffset.height)
        context.scaleBy(x: zoom, y: zoom)

        let vRect = visibleRect
        let detail = detailLevel

        // 1. Layer backgrounds
        drawLayerBackgrounds(in: &context, visibleRect: vRect)

        // 2. Edges
        for edge in spec.edges {
            drawEdge(edge, in: &context, visibleRect: vRect, detail: detail)
        }

        // 3. Nodes
        for node in spec.nodes {
            drawNode(node, in: &context, visibleRect: vRect, detail: detail)
        }

        // 4. Entry points
        if let entryPoints = spec.entryPoints {
            for entryPoint in entryPoints {
                drawEntryPoint(entryPoint, in: &context, visibleRect: vRect, detail: detail)
            }
        }
    }

    // MARK: - Layer Backgrounds

    private func drawLayerBackgrounds(in context: inout GraphicsContext, visibleRect vRect: CGRect) {
        // Group visible nodes by layer
        var nodesByLayer: [String: [SpecNode]] = [:]
        for node in spec.nodes {
            guard isLayerVisible(node.layer), nodePositions[node.id] != nil else { continue }
            nodesByLayer[node.layer, default: []].append(node)
        }

        for layer in spec.layers {
            guard isLayerVisible(layer.id),
                  let nodes = nodesByLayer[layer.id], !nodes.isEmpty else { continue }

            // Compute bounding box of all nodes in this layer
            var minX = CGFloat.infinity
            var minY = CGFloat.infinity
            var maxX = -CGFloat.infinity
            var maxY = -CGFloat.infinity

            for node in nodes {
                guard let pos = nodePositions[node.id] else { continue }
                let left = pos.x - nodeWidth / 2
                let top = pos.y - nodeHeight / 2
                let right = pos.x + nodeWidth / 2
                let bottom = pos.y + nodeHeight / 2
                minX = min(minX, left)
                minY = min(minY, top)
                maxX = max(maxX, right)
                maxY = max(maxY, bottom)
            }

            // Apply padding
            let layerRect = CGRect(
                x: minX - layerPadding,
                y: minY - layerPadding,
                width: (maxX - minX) + layerPadding * 2,
                height: (maxY - minY) + layerPadding * 2
            )

            // Viewport culling
            guard layerRect.intersects(vRect) else { continue }

            let layerColor = layer.swiftUIColor
            let cornerRadius: CGFloat = 16
            let roundedRect = RoundedRectangle(cornerRadius: cornerRadius)
            let path = roundedRect.path(in: layerRect)

            // Semi-transparent fill
            context.fill(path, with: .color(layerColor.opacity(0.06)))

            // Dashed outline stroke
            let dashStyle = StrokeStyle(
                lineWidth: 1.0,
                lineCap: .round,
                lineJoin: .round,
                dash: [8, 4]
            )
            context.stroke(path, with: .color(layerColor.opacity(0.25)), style: dashStyle)

            // Layer name label at top-left inside padding
            let labelPos = CGPoint(
                x: layerRect.minX + 12,
                y: layerRect.minY + 14
            )
            let labelText = Text(layer.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(layerColor.opacity(0.7))
            context.draw(
                context.resolve(labelText),
                at: labelPos,
                anchor: .topLeading
            )
        }
    }

    // MARK: - Edge Drawing

    private func drawEdge(
        _ edge: SpecEdge,
        in context: inout GraphicsContext,
        visibleRect vRect: CGRect,
        detail: DetailLevel
    ) {
        guard
            let fromNode = spec.nodes.first(where: { $0.id == edge.from }),
            let toNode = spec.nodes.first(where: { $0.id == edge.to }),
            isLayerVisible(fromNode.layer),
            isLayerVisible(toNode.layer)
        else { return }

        guard let fromPos = nodePositions[edge.from],
              let toPos = nodePositions[edge.to] else { return }

        // Viewport culling: check if the edge bounding box intersects the visible rect
        let edgeBounds = CGRect(
            x: min(fromPos.x, toPos.x) - 40,
            y: min(fromPos.y, toPos.y) - 40,
            width: abs(toPos.x - fromPos.x) + 80,
            height: abs(toPos.y - fromPos.y) + 80
        )
        guard edgeBounds.intersects(vRect) else { return }

        // Compute cubic Bezier control points (offset vertically)
        let dx = toPos.x - fromPos.x
        let dy = toPos.y - fromPos.y
        let dist = sqrt(dx * dx + dy * dy)
        let cpOffset = dist * 0.3

        let cp1 = CGPoint(x: fromPos.x, y: fromPos.y + cpOffset)
        let cp2 = CGPoint(x: toPos.x, y: toPos.y - cpOffset)

        var path = Path()
        path.move(to: fromPos)
        path.addCurve(to: toPos, control1: cp1, control2: cp2)

        // Determine edge style based on type
        let edgeType = edge.type ?? ""
        let strokeStyle: StrokeStyle
        let lineOpacity: CGFloat

        switch edgeType {
        case "calls":
            strokeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round)
            lineOpacity = 0.5
        case "triggers":
            strokeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 4])
            lineOpacity = 0.5
        case "publishes", "subscribes":
            strokeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 3])
            lineOpacity = 0.5
        case "reads", "writes":
            strokeStyle = StrokeStyle(lineWidth: 1.0, lineCap: .round)
            lineOpacity = 0.35
        default:
            strokeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round)
            lineOpacity = 0.5
        }

        // Also treat async flag
        let finalStyle: StrokeStyle
        if edge.async == true && edgeType != "triggers" {
            finalStyle = StrokeStyle(
                lineWidth: strokeStyle.lineWidth,
                lineCap: strokeStyle.lineCap,
                dash: [6, 4]
            )
        } else {
            finalStyle = strokeStyle
        }

        let edgeColor = colorForLayer(fromNode.layer).opacity(lineOpacity)
        context.stroke(path, with: .color(edgeColor), style: finalStyle)

        // Filled arrowhead at target boundary
        drawFilledArrowhead(
            to: toPos,
            cp: cp2,
            color: edgeColor,
            in: &context
        )

        // Midpoint label (only at full detail)
        if detail == .full, let label = edge.label {
            let mid = bezierPoint(t: 0.5, p0: fromPos, p1: cp1, p2: cp2, p3: toPos)
            drawEdgeLabel(label, at: mid, color: colorForLayer(fromNode.layer), in: &context)
        }
    }

    /// Evaluates a cubic Bezier at parameter t.
    private func bezierPoint(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        return CGPoint(
            x: uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x,
            y: uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
        )
    }

    private func drawFilledArrowhead(
        to: CGPoint,
        cp: CGPoint,
        color: Color,
        in context: inout GraphicsContext
    ) {
        let dx = to.x - cp.x
        let dy = to.y - cp.y
        let angle = atan2(dy, dx)
        let arrowLength: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6

        let targetPoint = nodeEdgeIntersection(center: to, angle: angle + .pi)

        let tip = targetPoint
        let left = CGPoint(
            x: tip.x - arrowLength * cos(angle - arrowAngle),
            y: tip.y - arrowLength * sin(angle - arrowAngle)
        )
        let right = CGPoint(
            x: tip.x - arrowLength * cos(angle + arrowAngle),
            y: tip.y - arrowLength * sin(angle + arrowAngle)
        )

        var path = Path()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()

        context.fill(path, with: .color(color))
    }

    /// Returns the point on the node boundary where a ray from `center` at `angle` exits.
    private func nodeEdgeIntersection(center: CGPoint, angle: CGFloat) -> CGPoint {
        let hw = nodeWidth / 2
        let hh = nodeHeight / 2
        let cosA = cos(angle)
        let sinA = sin(angle)

        let tx = cosA != 0 ? abs(hw / cosA) : CGFloat.infinity
        let ty = sinA != 0 ? abs(hh / sinA) : CGFloat.infinity
        let t = min(tx, ty)

        return CGPoint(
            x: center.x + cosA * t,
            y: center.y + sinA * t
        )
    }

    private func drawEdgeLabel(
        _ label: String,
        at point: CGPoint,
        color: Color,
        in context: inout GraphicsContext
    ) {
        let text = Text(label)
            .font(.caption2)
            .foregroundColor(.primary.opacity(0.8))
        let resolved = context.resolve(text)

        // Draw a background pill
        let textSize = resolved.measure(in: CGSize(width: 200, height: 40))
        let pillRect = CGRect(
            x: point.x - textSize.width / 2 - 6,
            y: point.y - textSize.height / 2 - 3,
            width: textSize.width + 12,
            height: textSize.height + 6
        )
        let pill = RoundedRectangle(cornerRadius: 8).path(in: pillRect)
        context.fill(pill, with: .color(color.opacity(0.08)))
        context.stroke(pill, with: .color(color.opacity(0.15)), style: StrokeStyle(lineWidth: 0.5))

        context.draw(resolved, at: point)
    }

    // MARK: - Node Drawing

    private func drawNode(
        _ node: SpecNode,
        in context: inout GraphicsContext,
        visibleRect vRect: CGRect,
        detail: DetailLevel
    ) {
        guard isLayerVisible(node.layer) else { return }
        guard let position = nodePositions[node.id] else { return }

        let layerColor = colorForLayer(node.layer)
        let isSelected = node.id == selectedNodeID
        let isHovered = node.id == hoveredNodeID

        switch detail {
        case .minimal:
            let circleRect = CGRect(
                x: position.x - 8,
                y: position.y - 8,
                width: 16,
                height: 16
            )
            guard circleRect.intersects(vRect) else { return }
            let circlePath = Circle().path(in: circleRect)
            context.fill(circlePath, with: .color(layerColor.opacity(isSelected ? 0.8 : 0.6)))

        case .reduced:
            let rect = nodeRect(at: position)
            guard rect.intersects(vRect) else { return }
            drawNodeBody(
                node: node,
                position: position,
                rect: rect,
                layerColor: layerColor,
                isSelected: isSelected,
                isHovered: isHovered,
                showBadge: false,
                in: &context
            )

        case .full:
            let rect = nodeRect(at: position)
            guard rect.intersects(vRect) else { return }
            drawNodeBody(
                node: node,
                position: position,
                rect: rect,
                layerColor: layerColor,
                isSelected: isSelected,
                isHovered: isHovered,
                showBadge: true,
                in: &context
            )
        }
    }

    private func nodeRect(at position: CGPoint) -> CGRect {
        CGRect(
            x: position.x - nodeWidth / 2,
            y: position.y - nodeHeight / 2,
            width: nodeWidth,
            height: nodeHeight
        )
    }

    private func drawNodeBody(
        node: SpecNode,
        position: CGPoint,
        rect: CGRect,
        layerColor: Color,
        isSelected: Bool,
        isHovered: Bool,
        showBadge: Bool,
        in context: inout GraphicsContext
    ) {
        let roundedRect = RoundedRectangle(cornerRadius: nodeCornerRadius)
        let path = roundedRect.path(in: rect)

        // Hover: outer glow via shadow
        if isHovered {
            context.drawLayer { innerCtx in
                innerCtx.addFilter(.shadow(
                    color: layerColor.opacity(0.35),
                    radius: 8,
                    x: 0,
                    y: 0
                ))
                let expandedRect = rect.insetBy(dx: -2, dy: -2)
                let expandedPath = RoundedRectangle(cornerRadius: nodeCornerRadius + 2).path(in: expandedRect)
                innerCtx.fill(expandedPath, with: .color(layerColor.opacity(0.05)))
            }
        }

        // Fill
        let fillOpacity: CGFloat
        if isSelected {
            fillOpacity = 0.3
        } else if isHovered {
            fillOpacity = 0.25
        } else {
            fillOpacity = 0.15
        }
        context.fill(path, with: .color(layerColor.opacity(fillOpacity)))

        // Stroke
        let strokeColor = isSelected ? layerColor : layerColor.opacity(0.5)
        let lineWidth: CGFloat = isSelected ? 2.5 : (isHovered ? 2.0 : 1.5)
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: lineWidth))

        // Node name
        let nameText = Text(node.name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primary)
        context.draw(
            context.resolve(nameText),
            at: CGPoint(x: position.x, y: position.y - (showBadge ? 8 : 0))
        )

        // Layer badge (full detail only)
        if showBadge, let layer = spec.layers.first(where: { $0.id == node.layer }) {
            let badgeText = Text(layer.name)
                .font(.system(size: 9))
                .foregroundColor(layerColor)
            context.draw(
                context.resolve(badgeText),
                at: CGPoint(x: position.x, y: position.y + 12)
            )
        }
    }

    // MARK: - Entry Point Drawing

    private func drawEntryPoint(
        _ entryPoint: EntryPoint,
        in context: inout GraphicsContext,
        visibleRect vRect: CGRect,
        detail: DetailLevel
    ) {
        guard
            let node = spec.nodes.first(where: { $0.id == entryPoint.node }),
            isLayerVisible(node.layer)
        else { return }

        guard let nodePos = nodePositions[entryPoint.node] else { return }

        let indicatorPos = CGPoint(x: nodePos.x - nodeWidth / 2 - 20, y: nodePos.y)

        let indicatorBounds = CGRect(
            x: indicatorPos.x - 10,
            y: indicatorPos.y - 10,
            width: 20,
            height: 20
        )
        guard indicatorBounds.intersects(vRect) else { return }

        switch detail {
        case .minimal:
            return

        case .reduced:
            let dotRect = CGRect(
                x: indicatorPos.x - 4,
                y: indicatorPos.y - 4,
                width: 8,
                height: 8
            )
            let dotPath = Circle().path(in: dotRect)
            context.fill(dotPath, with: .color(.orange.opacity(0.7)))

        case .full:
            var path = Path()
            path.move(to: CGPoint(x: indicatorPos.x, y: indicatorPos.y - 6))
            path.addLine(to: CGPoint(x: indicatorPos.x + 6, y: indicatorPos.y))
            path.addLine(to: CGPoint(x: indicatorPos.x, y: indicatorPos.y + 6))
            path.addLine(to: CGPoint(x: indicatorPos.x - 6, y: indicatorPos.y))
            path.closeSubpath()

            context.fill(path, with: .color(.orange.opacity(0.8)))
        }
    }

    // MARK: - Helpers

    private func colorForLayer(_ layerID: String) -> Color {
        spec.layers.first(where: { $0.id == layerID })?.swiftUIColor ?? .gray
    }

    private func isLayerVisible(_ layerID: String) -> Bool {
        visibleLayerIDs.contains(layerID)
    }
}
