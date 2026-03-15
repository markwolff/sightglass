import SwiftUI

/// A SwiftUI view representing an edge (data flow) between two nodes.
///
/// Used for overlay-based rendering or as a reference for Canvas drawing.
/// The Canvas-based DiagramRenderer handles primary rendering; this view
/// can be used for richer interactive overlays in the future.
struct EdgeView: View {
    let edge: SpecEdge
    let fromPosition: CGPoint
    let toPosition: CGPoint

    var body: some View {
        ZStack {
            // Edge line
            EdgeShape(from: fromPosition, to: toPosition)
                .stroke(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // Label at midpoint
            if let label = edge.label {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(.windowBackgroundColor).opacity(0.8))
                    .cornerRadius(4)
                    .position(midpoint)
            }
        }
    }

    private var midpoint: CGPoint {
        CGPoint(
            x: (fromPosition.x + toPosition.x) / 2,
            y: (fromPosition.y + toPosition.y) / 2
        )
    }
}

/// A Shape that draws a line between two points.
struct EdgeShape: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }
}
