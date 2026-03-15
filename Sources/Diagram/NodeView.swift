import SwiftUI

/// A SwiftUI view representing a single node in the diagram.
///
/// Used for overlay-based rendering or as a reference for Canvas drawing.
/// The Canvas-based DiagramRenderer handles primary rendering; this view
/// can be used for richer interactive overlays in the future.
struct NodeView: View {
    let node: SpecNode
    let layer: SpecLayer?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(node.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            if let layer = layer {
                Text(layer.name)
                    .font(.system(size: 9))
                    .foregroundColor(layer.swiftUIColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(layerColor.opacity(isSelected ? 0.3 : 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? layerColor : layerColor.opacity(0.5),
                    lineWidth: isSelected ? 2.5 : 1.5
                )
        )
        .shadow(color: isSelected ? layerColor.opacity(0.3) : .clear, radius: 8)
    }

    private var layerColor: Color {
        layer?.swiftUIColor ?? .gray
    }
}
