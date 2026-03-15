import Foundation
import SwiftUI

/// A layer groups related nodes (e.g., API Layer, Business Logic, Data Access).
struct SpecLayer: Codable, Identifiable, Hashable {
    /// Unique identifier for this layer (e.g., "api")
    let id: String

    /// Human-readable name (e.g., "API Layer")
    let name: String

    /// Hex color string for rendering this layer (e.g., "#4A90D9")
    let color: String

    /// Converts the hex color string to a SwiftUI Color.
    var swiftUIColor: Color {
        Color(hex: color) ?? .gray
    }
}

// MARK: - Color Hex Extension

extension Color {
    /// Creates a Color from a hex string like "#4A90D9" or "4A90D9".
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6 else { return nil }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgbValue) else { return nil }

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
