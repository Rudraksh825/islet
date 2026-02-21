import SwiftUI

struct AVConferenceView: View {
    @ObservedObject var viewModel: IslandViewModel
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 10) {
            // Live indicator dot
            Circle()
                .fill(viewModel.cameraActive ? Color.red : Color.green)
                .frame(width: 8, height: 8)
                .scaleEffect(pulsing ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
                .onAppear { pulsing = true }

            VStack(alignment: .leading, spacing: 2) {
                if viewModel.cameraActive {
                    Label("Camera Active", systemImage: "camera.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
                if viewModel.micActive {
                    Label("Mic Active", systemImage: "mic.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
                if !viewModel.avAppName.isEmpty {
                    Text(viewModel.avAppName)
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.5))
                }
            }

            Spacer()

            Button(action: { viewModel.muteMic() }) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.red.opacity(0.3))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
