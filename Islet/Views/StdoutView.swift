import SwiftUI

struct StdoutView: View {
    @ObservedObject var viewModel: IslandViewModel
    @State private var blink = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green)

                Text("stdout")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.green)

                // Blinking cursor
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 6, height: 10)
                    .opacity(blink ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: blink)
                    .onAppear { blink = true }
            }

            ForEach(viewModel.stdoutLines.prefix(3), id: \.self) { line in
                Text(line.truncated(to: 50))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(white: 0.7))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
