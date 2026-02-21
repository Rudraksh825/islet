import SwiftUI
import AppKit

struct ColorSamplerView: View {
    let color: NSColor
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(color))
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(white: 0.3), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(color.hexString)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                let rgb = rgbComponents
                Text("R:\(rgb.r) G:\(rgb.g) B:\(rgb.b)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(white: 0.6))
            }

            Spacer()

            Button(copied ? "Copied!" : "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(color.hexString, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white)
            .cornerRadius(6)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rgbComponents: (r: Int, g: Int, b: Int) {
        guard let rgb = color.usingColorSpace(.sRGB) else { return (0, 0, 0) }
        return (
            Int(rgb.redComponent * 255),
            Int(rgb.greenComponent * 255),
            Int(rgb.blueComponent * 255)
        )
    }
}
