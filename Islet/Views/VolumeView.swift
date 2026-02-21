import SwiftUI

// Reads directly from viewModel so the bar updates in real-time as the user moves the volume slider
struct VolumeView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.volumeIsMuted ? "speaker.slash.fill" : speakerSymbol)
                .font(.system(size: 18))
                .foregroundColor(viewModel.volumeIsMuted ? .red : .white)
                .frame(width: 24)
                .animation(.easeInOut(duration: 0.15), value: viewModel.volumeIsMuted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.25)).frame(height: 6)
                    Capsule()
                        .fill(viewModel.volumeIsMuted ? Color.red : Color.white)
                        .frame(
                            width: geo.size.width * CGFloat(viewModel.volumeIsMuted ? 0 : viewModel.volumeLevel),
                            height: 6
                        )
                        .animation(.easeOut(duration: 0.08), value: viewModel.volumeLevel)
                }
            }
            .frame(height: 6)

            Text(viewModel.volumeIsMuted ? "Muted" : "\(Int(viewModel.volumeLevel * 100))%")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, alignment: .trailing)
        }
        .frame(maxHeight: .infinity)
    }

    private var speakerSymbol: String {
        if viewModel.volumeLevel == 0 { return "speaker.fill" }
        if viewModel.volumeLevel < 0.33 { return "speaker.wave.1.fill" }
        if viewModel.volumeLevel < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
