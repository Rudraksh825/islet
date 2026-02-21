import Foundation
import AppKit
import SwiftUI

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var swiftUIColor: Color { Color(self) }
}

extension Color {
    static let islandBackground = Color.black
    static let islandText = Color.white
    static let islandSecondary = Color(white: 0.6)
}

extension Double {
    /// Format bytes/sec to human-readable string
    var formattedBandwidth: String {
        if self < 1024 { return String(format: "%.0f B/s", self) }
        if self < 1_048_576 { return String(format: "%.1f KB/s", self / 1024) }
        return String(format: "%.1f MB/s", self / 1_048_576)
    }

    var formattedTemp: String { String(format: "%.0f°", self) }
    var formattedPercent: String { String(format: "%.0f%%", self * 100) }
}

extension String {
    func truncated(to length: Int) -> String {
        count > length ? String(prefix(length)) + "…" : self
    }
}

extension View {
    func islandCard() -> some View {
        self
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
