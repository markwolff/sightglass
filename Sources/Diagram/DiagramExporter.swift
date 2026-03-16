import SwiftUI
import AppKit
import SightglassCore

/// Exports the current diagram state to PNG or SVG with deterministic framing.
struct DiagramExporter {
    let spec: CodeSpec
    let nodePositions: [String: CGPoint]
    let visibleLayerIDs: Set<String>

    private let nodeWidth: CGFloat = 160
    private let nodeHeight: CGFloat = 60
    private let nodeCornerRadius: CGFloat = 10
    private let exportPadding: CGFloat = 80

    // MARK: - Content Bounds

    private var contentBounds: CGRect {
        let visibleNodes = spec.nodes.filter { visibleLayerIDs.contains($0.layer) }
        guard !visibleNodes.isEmpty else {
            return CGRect(x: 0, y: 0, width: 400, height: 300)
        }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for node in visibleNodes {
            guard let pos = nodePositions[node.id] else { continue }
            minX = min(minX, pos.x - nodeWidth / 2)
            maxX = max(maxX, pos.x + nodeWidth / 2)
            minY = min(minY, pos.y - nodeHeight / 2)
            maxY = max(maxY, pos.y + nodeHeight / 2)
        }

        return CGRect(
            x: minX - exportPadding,
            y: minY - exportPadding,
            width: (maxX - minX) + exportPadding * 2,
            height: (maxY - minY) + exportPadding * 2
        )
    }

    // MARK: - PNG Export

    func exportPNG(to url: URL, scale: CGFloat = 2.0) throws {
        let bounds = contentBounds
        let pixelWidth = Int(bounds.width * scale)
        let pixelHeight = Int(bounds.height * scale)

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ExportError.bitmapCreationFailed
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            NSGraphicsContext.restoreGraphicsState()
            throw ExportError.contextCreationFailed
        }
        NSGraphicsContext.current = context
        context.shouldAntialias = true

        // Scale and translate to fit content
        let transform = NSAffineTransform()
        transform.scale(by: scale)
        transform.translateX(by: -bounds.origin.x, yBy: -bounds.origin.y)
        transform.concat()

        // Draw white background
        NSColor.white.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: bounds.size))

        // Draw layer backgrounds, edges, nodes
        drawLayerBackgroundsAppKit(in: bounds)
        drawEdgesAppKit()
        drawNodesAppKit()

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ExportError.pngEncodingFailed
        }

        try pngData.write(to: url)
    }

    // MARK: - SVG Export

    func exportSVG(to url: URL) throws {
        let bounds = contentBounds
        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg"
             viewBox="\(Int(bounds.origin.x)) \(Int(bounds.origin.y)) \(Int(bounds.width)) \(Int(bounds.height))"
             width="\(Int(bounds.width))" height="\(Int(bounds.height))">
        <defs>
            <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
                <polygon points="0 0, 10 3.5, 0 7" fill="#888"/>
            </marker>
        </defs>
        <rect x="\(Int(bounds.origin.x))" y="\(Int(bounds.origin.y))" width="\(Int(bounds.width))" height="\(Int(bounds.height))" fill="white"/>

        """

        // Layer backgrounds
        svg += svgLayerBackgrounds()

        // Edges (sorted for determinism)
        for edge in spec.edges.sorted(by: { $0.id < $1.id }) {
            svg += svgEdge(edge)
        }

        // Nodes (sorted for determinism)
        for node in spec.nodes.sorted(by: { $0.id < $1.id }) {
            svg += svgNode(node)
        }

        svg += "</svg>\n"

        try svg.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - AppKit Drawing Helpers

    private func drawLayerBackgroundsAppKit(in bounds: CGRect) {
        let orderedLayers = spec.layers.sorted { $0.rank < $1.rank }

        for layer in orderedLayers {
            guard visibleLayerIDs.contains(layer.id) else { continue }

            let layerNodes = spec.nodes.filter { $0.layer == layer.id }
            guard !layerNodes.isEmpty else { continue }

            var minX = CGFloat.greatestFiniteMagnitude
            var minY = CGFloat.greatestFiniteMagnitude
            var maxX = -CGFloat.greatestFiniteMagnitude
            var maxY = -CGFloat.greatestFiniteMagnitude

            for node in layerNodes {
                guard let pos = nodePositions[node.id] else { continue }
                minX = min(minX, pos.x - nodeWidth / 2)
                maxX = max(maxX, pos.x + nodeWidth / 2)
                minY = min(minY, pos.y - nodeHeight / 2)
                maxY = max(maxY, pos.y + nodeHeight / 2)
            }

            let padding: CGFloat = 40
            let rect = NSRect(
                x: minX - padding,
                y: minY - padding,
                width: (maxX - minX) + padding * 2,
                height: (maxY - minY) + padding * 2
            )

            let nsColor = nsColorFromHex(layer.color)

            // Fill
            nsColor.withAlphaComponent(0.06).setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
            path.fill()

            // Dashed stroke
            nsColor.withAlphaComponent(0.25).setStroke()
            path.lineWidth = 1.5
            path.setLineDash([8, 4], count: 2, phase: 0)
            path.stroke()

            // Label
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: nsColor.withAlphaComponent(0.6),
            ]
            let labelStr = NSAttributedString(string: layer.name, attributes: attrs)
            labelStr.draw(at: NSPoint(x: rect.minX + 12, y: rect.minY + 8))
        }
    }

    private func drawEdgesAppKit() {
        for edge in spec.edges.sorted(by: { $0.id < $1.id }) {
            guard let fromNode = spec.nodes.first(where: { $0.id == edge.from }),
                  let toNode = spec.nodes.first(where: { $0.id == edge.to }),
                  visibleLayerIDs.contains(fromNode.layer),
                  visibleLayerIDs.contains(toNode.layer),
                  let fromPos = nodePositions[edge.from],
                  let toPos = nodePositions[edge.to] else { continue }

            let path = NSBezierPath()
            let dy = toPos.y - fromPos.y
            let controlOffset = abs(dy) * 0.3
            let cp1 = NSPoint(x: fromPos.x, y: fromPos.y + controlOffset)
            let cp2 = NSPoint(x: toPos.x, y: toPos.y - controlOffset)

            path.move(to: NSPoint(x: fromPos.x, y: fromPos.y))
            path.curve(to: NSPoint(x: toPos.x, y: toPos.y), controlPoint1: cp1, controlPoint2: cp2)

            NSColor.gray.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1.5

            let edgeType = edge.type ?? ""
            switch edgeType {
            case "triggers":
                path.setLineDash([6, 4], count: 2, phase: 0)
            case "publishes", "subscribes":
                path.setLineDash([2, 3], count: 2, phase: 0)
            case "reads", "writes":
                path.lineWidth = 1.0
            default:
                break
            }
            if edge.async == true {
                path.setLineDash([6, 4], count: 2, phase: 0)
            }

            path.stroke()
        }
    }

    private func drawNodesAppKit() {
        for node in spec.nodes.sorted(by: { $0.id < $1.id }) {
            guard visibleLayerIDs.contains(node.layer),
                  let pos = nodePositions[node.id] else { continue }

            let rect = NSRect(
                x: pos.x - nodeWidth / 2,
                y: pos.y - nodeHeight / 2,
                width: nodeWidth,
                height: nodeHeight
            )

            let nsColor = nsColorFromHex(
                spec.layers.first(where: { $0.id == node.layer })?.color ?? "#888888"
            )

            // Fill
            nsColor.withAlphaComponent(0.15).setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: nodeCornerRadius, yRadius: nodeCornerRadius)
            path.fill()

            // Stroke
            nsColor.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1.5
            path.stroke()

            // Name label
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.black,
            ]
            let nameStr = NSAttributedString(string: node.name, attributes: nameAttrs)
            let nameSize = nameStr.size()
            nameStr.draw(at: NSPoint(
                x: pos.x - nameSize.width / 2,
                y: pos.y - nameSize.height / 2
            ))
        }
    }

    // MARK: - SVG Helpers

    private func svgLayerBackgrounds() -> String {
        var result = ""
        let orderedLayers = spec.layers.sorted { $0.rank < $1.rank }

        for layer in orderedLayers {
            guard visibleLayerIDs.contains(layer.id) else { continue }

            let layerNodes = spec.nodes.filter { $0.layer == layer.id }
            guard !layerNodes.isEmpty else { continue }

            var minX = CGFloat.greatestFiniteMagnitude
            var minY = CGFloat.greatestFiniteMagnitude
            var maxX = -CGFloat.greatestFiniteMagnitude
            var maxY = -CGFloat.greatestFiniteMagnitude

            for node in layerNodes {
                guard let pos = nodePositions[node.id] else { continue }
                minX = min(minX, pos.x - nodeWidth / 2)
                maxX = max(maxX, pos.x + nodeWidth / 2)
                minY = min(minY, pos.y - nodeHeight / 2)
                maxY = max(maxY, pos.y + nodeHeight / 2)
            }

            let padding: CGFloat = 40
            let hex = layer.color.hasPrefix("#") ? layer.color : "#\(layer.color)"

            result += """
            <rect x="\(Int(minX - padding))" y="\(Int(minY - padding))"
                  width="\(Int(maxX - minX + padding * 2))" height="\(Int(maxY - minY + padding * 2))"
                  rx="12" ry="12" fill="\(hex)" fill-opacity="0.06"
                  stroke="\(hex)" stroke-opacity="0.25" stroke-width="1.5"
                  stroke-dasharray="8 4"/>
            <text x="\(Int(minX - padding + 12))" y="\(Int(minY - padding + 20))"
                  font-size="11" font-weight="500" fill="\(hex)" fill-opacity="0.6">\(escapeXML(layer.name))</text>

            """
        }

        return result
    }

    private func svgEdge(_ edge: SpecEdge) -> String {
        guard let fromNode = spec.nodes.first(where: { $0.id == edge.from }),
              let toNode = spec.nodes.first(where: { $0.id == edge.to }),
              visibleLayerIDs.contains(fromNode.layer),
              visibleLayerIDs.contains(toNode.layer),
              let fromPos = nodePositions[edge.from],
              let toPos = nodePositions[edge.to] else { return "" }

        let dy = toPos.y - fromPos.y
        let controlOffset = abs(dy) * 0.3
        let cp1x = Int(fromPos.x)
        let cp1y = Int(fromPos.y + controlOffset)
        let cp2x = Int(toPos.x)
        let cp2y = Int(toPos.y - controlOffset)

        var dashArray = ""
        var strokeWidth = "1.5"
        let edgeType = edge.type ?? ""

        switch edgeType {
        case "triggers":
            dashArray = " stroke-dasharray=\"6 4\""
        case "publishes", "subscribes":
            dashArray = " stroke-dasharray=\"2 3\""
        case "reads", "writes":
            strokeWidth = "1.0"
        default:
            break
        }
        if edge.async == true {
            dashArray = " stroke-dasharray=\"6 4\""
        }

        var result = """
        <path d="M \(Int(fromPos.x)) \(Int(fromPos.y)) C \(cp1x) \(cp1y) \(cp2x) \(cp2y) \(Int(toPos.x)) \(Int(toPos.y))"
              fill="none" stroke="#888" stroke-opacity="0.5" stroke-width="\(strokeWidth)"\(dashArray)
              marker-end="url(#arrowhead)"/>

        """

        if let label = edge.label {
            let midX = Int((fromPos.x + toPos.x) / 2)
            let midY = Int((fromPos.y + toPos.y) / 2 - 12)
            result += """
            <text x="\(midX)" y="\(midY)" font-size="10" fill="#888" text-anchor="middle">\(escapeXML(label))</text>

            """
        }

        return result
    }

    private func svgNode(_ node: SpecNode) -> String {
        guard visibleLayerIDs.contains(node.layer),
              let pos = nodePositions[node.id] else { return "" }

        let hex = spec.layers.first(where: { $0.id == node.layer })?.color ?? "#888888"
        let colorHex = hex.hasPrefix("#") ? hex : "#\(hex)"

        let x = Int(pos.x - nodeWidth / 2)
        let y = Int(pos.y - nodeHeight / 2)

        return """
        <rect x="\(x)" y="\(y)" width="\(Int(nodeWidth))" height="\(Int(nodeHeight))"
              rx="\(Int(nodeCornerRadius))" ry="\(Int(nodeCornerRadius))"
              fill="\(colorHex)" fill-opacity="0.15"
              stroke="\(colorHex)" stroke-opacity="0.5" stroke-width="1.5"/>
        <text x="\(Int(pos.x))" y="\(Int(pos.y + 4))" font-size="12" font-weight="600"
              text-anchor="middle" fill="black">\(escapeXML(node.name))</text>

        """
    }

    // MARK: - Utilities

    private func nsColorFromHex(_ hex: String) -> NSColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6 else { return .gray }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgbValue) else { return .gray }

        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0

        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    enum ExportError: LocalizedError {
        case bitmapCreationFailed
        case contextCreationFailed
        case pngEncodingFailed

        var errorDescription: String? {
            switch self {
            case .bitmapCreationFailed:
                return "Failed to create bitmap for PNG export."
            case .contextCreationFailed:
                return "Failed to create graphics context for PNG export."
            case .pngEncodingFailed:
                return "Failed to encode PNG data."
            }
        }
    }
}
