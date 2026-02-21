import SwiftUI

struct ANEView: View {
    @ObservedObject var viewModel: IslandViewModel
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Text("⬡")
                .font(.system(size: 16))
                .foregroundColor(.purple)
                .scaleEffect(pulsing ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulsing)
                .onAppear { pulsing = true }

            VStack(alignment: .leading, spacing: 2) {
                Text("ANE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text("Active")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
