import SwiftUI
import SightglassCore

/// The main diagram view that renders the code architecture graph.
///
/// Uses SwiftUI Canvas for custom 2D rendering of nodes and edges.
/// Supports cursor-anchored zoom, pan, hover tracking, and tap selection.
struct DiagramView: View {
    let spec: CodeSpec

    @EnvironmentObject var appState: AppState

    /// Accumulated magnification from pinch gesture
    @State private var gestureZoom: CGFloat = 1.0

    /// Accumulated drag offset from pan gesture
    @State private var gesturePan: CGSize = .zero

    /// Last known mouse location in view coordinates
    @State private var lastMouseLocation: CGPoint?

    /// Tracked canvas size for fit-to-screen
    @State private var canvasSize: CGSize = .zero

    private let nodeWidth: CGFloat = 160
    private let nodeHeight: CGFloat = 60

    var body: some View {
        Canvas { context, size in
            if canvasSize != size {
                DispatchQueue.main.async {
                    canvasSize = size
                }
            }

            let renderer = DiagramRenderer(
                spec: spec,
                nodePositions: appState.nodePositions,
                selectedNodeID: appState.selectedNode?.id,
                hoveredNodeID: appState.hoveredNodeID,
                visibleLayerIDs: appState.visibleLayerIDs,
                zoom: effectiveZoom,
                panOffset: combinedPanOffset,
                canvasSize: size
            )
            renderer.render(in: &context)
        }
        .gesture(magnificationGesture)
        .gesture(panGesture)
        .simultaneousGesture(tapGesture)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                lastMouseLocation = location
                let graphPoint = screenToGraph(location)
                if let nodeID = hitTest(at: graphPoint) {
                    if appState.hoveredNodeID != nodeID {
                        appState.hoveredNodeID = nodeID
                        NSCursor.pointingHand.push()
                    }
                } else {
                    if appState.hoveredNodeID != nil {
                        appState.hoveredNodeID = nil
                        NSCursor.pop()
                    }
                }
            case .ended:
                if appState.hoveredNodeID != nil {
                    appState.hoveredNodeID = nil
                    NSCursor.pop()
                }
                lastMouseLocation = nil
            @unknown default:
                break
            }
        }
        .onAppear {
            if appState.nodePositions.isEmpty {
                appState.computeLayout(for: spec)
            }
        }
    }

    // MARK: - Effective Transform

    private var effectiveZoom: CGFloat {
        clampZoom(appState.zoomLevel * gestureZoom)
    }

    private var combinedPanOffset: CGSize {
        CGSize(
            width: appState.panOffset.width + gesturePan.width,
            height: appState.panOffset.height + gesturePan.height
        )
    }

    private func clampZoom(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, 0.1), 5.0)
    }

    // MARK: - Coordinate Transforms

    /// Converts a screen-space point to graph-space coordinates.
    private func screenToGraph(_ point: CGPoint) -> CGPoint {
        let zoom = effectiveZoom
        let offset = combinedPanOffset
        return CGPoint(
            x: (point.x - offset.width) / zoom,
            y: (point.y - offset.height) / zoom
        )
    }

    // MARK: - Hit Testing

    /// Returns the node ID at the given graph-space point, if any.
    private func hitTest(at graphPoint: CGPoint) -> String? {
        let nodeSize = CGSize(width: nodeWidth, height: nodeHeight)
        for (nodeID, position) in appState.nodePositions {
            guard
                let node = spec.nodes.first(where: { $0.id == nodeID }),
                appState.visibleLayerIDs.contains(node.layer)
            else {
                continue
            }

            let nodeRect = CGRect(
                x: position.x - nodeSize.width / 2,
                y: position.y - nodeSize.height / 2,
                width: nodeSize.width,
                height: nodeSize.height
            )
            if nodeRect.contains(graphPoint) {
                return nodeID
            }
        }
        return nil
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newGestureZoom = value.magnification
                let proposedZoom = clampZoom(appState.zoomLevel * newGestureZoom)

                // Cursor-anchored zoom: adjust pan so the anchor point stays fixed
                if let anchor = lastMouseLocation {
                    let oldZoom = effectiveZoom
                    let newZoom = proposedZoom

                    // Compute the graph point under the cursor at old zoom
                    let graphX = (anchor.x - appState.panOffset.width - gesturePan.width) / oldZoom
                    let graphY = (anchor.y - appState.panOffset.height - gesturePan.height) / oldZoom

                    // Compute what gesturePan should be so that graphPoint maps back to anchor
                    let newPanX = anchor.x - graphX * newZoom - appState.panOffset.width
                    let newPanY = anchor.y - graphY * newZoom - appState.panOffset.height

                    gesturePan = CGSize(width: newPanX, height: newPanY)
                }

                gestureZoom = proposedZoom / appState.zoomLevel
            }
            .onEnded { value in
                let finalZoom = clampZoom(appState.zoomLevel * value.magnification)
                appState.zoomLevel = finalZoom
                appState.panOffset = CGSize(
                    width: appState.panOffset.width + gesturePan.width,
                    height: appState.panOffset.height + gesturePan.height
                )
                gestureZoom = 1.0
                gesturePan = .zero
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                gesturePan = value.translation
            }
            .onEnded { value in
                appState.panOffset = CGSize(
                    width: appState.panOffset.width + value.translation.width,
                    height: appState.panOffset.height + value.translation.height
                )
                gesturePan = .zero
            }
    }

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let graphPoint = screenToGraph(value.location)
                if let nodeID = hitTest(at: graphPoint) {
                    appState.selectNode(id: nodeID)
                } else {
                    appState.clearSelection()
                }
            }
    }
}
