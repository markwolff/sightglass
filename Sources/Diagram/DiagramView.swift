import SwiftUI
import SightglassCore

/// The main diagram view that renders the code architecture graph.
///
/// Uses SwiftUI Canvas for custom 2D rendering of nodes and edges.
/// Supports pan and zoom via gesture modifiers.
struct DiagramView: View {
    let spec: CodeSpec

    @EnvironmentObject var appState: AppState

    /// Accumulated magnification from pinch gesture
    @State private var gestureZoom: CGFloat = 1.0

    /// Accumulated drag offset from pan gesture
    @State private var gesturePan: CGSize = .zero

    var body: some View {
        Canvas { context, size in
            let renderer = DiagramRenderer(
                spec: spec,
                nodePositions: appState.nodePositions,
                selectedNodeID: appState.selectedNode?.id,
                zoom: appState.zoomLevel * gestureZoom,
                panOffset: combinedPanOffset,
                canvasSize: size
            )
            renderer.render(in: &context)
        }
        .gesture(magnificationGesture)
        .gesture(panGesture)
        .simultaneousGesture(tapGesture)
        .onAppear {
            if appState.nodePositions.isEmpty {
                appState.computeLayout(for: spec)
            }
        }
    }

    // MARK: - Combined Transform

    private var combinedPanOffset: CGSize {
        CGSize(
            width: appState.panOffset.width + gesturePan.width,
            height: appState.panOffset.height + gesturePan.height
        )
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureZoom = value.magnification
            }
            .onEnded { value in
                appState.zoomLevel *= value.magnification
                gestureZoom = 1.0
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
                handleTap(at: value.location)
            }
    }

    // MARK: - Hit Testing

    private func handleTap(at point: CGPoint) {
        // TODO: Transform point by current zoom/pan to get graph coordinates
        let zoom = appState.zoomLevel * gestureZoom
        let offset = combinedPanOffset

        let graphPoint = CGPoint(
            x: (point.x - offset.width) / zoom,
            y: (point.y - offset.height) / zoom
        )

        // Find the node at the tapped point
        let nodeSize = CGSize(width: 160, height: 60)
        for (nodeID, position) in appState.nodePositions {
            let nodeRect = CGRect(
                x: position.x - nodeSize.width / 2,
                y: position.y - nodeSize.height / 2,
                width: nodeSize.width,
                height: nodeSize.height
            )
            if nodeRect.contains(graphPoint) {
                appState.selectNode(id: nodeID)
                return
            }
        }

        // Tapped on empty space, clear selection
        appState.clearSelection()
    }
}
