import SwiftUI

struct CollapsedView: View {
    @ObservedObject var viewModel: IslandViewModel
    @State private var opacity: Double = 0.3

    var body: some View {
        // Breathing animation when idle, faster pulse when CPU is high
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: 6, height: 6)
            .onAppear {
                let duration = 1.0 / max(0.3, viewModel.cpuUsage * 2 + 0.3)
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    opacity = 0.8
                }
            }
    }
}
