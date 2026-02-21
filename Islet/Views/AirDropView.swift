import SwiftUI

struct AirDropView: View {
    let fileName: String
    @State private var animating = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.to.line.alt")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .scaleEffect(animating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animating)
                .onAppear { animating = true }

            VStack(alignment: .leading, spacing: 2) {
                Text("AirDrop")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.5))
                Text(fileName.truncated(to: 24))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
