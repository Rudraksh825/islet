import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var viewModel: IslandViewModel
    @State private var showControls = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                // Album art
                Button(action: { viewModel.togglePlayPause() }) {
                    Group {
                        if let art = viewModel.nowPlayingArt {
                            Image(nsImage: art)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "music.note")
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    // Marquee title
                    Text(viewModel.nowPlayingTrack.isEmpty ? "Not Playing" : viewModel.nowPlayingTrack)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(viewModel.nowPlayingArtist)
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.6))
                        .lineLimit(1)
                }

                Spacer()

                if showControls {
                    HStack(spacing: 8) {
                        Button(action: { viewModel.skipPrevious() }) {
                            Image(systemName: "backward.fill").font(.system(size: 11))
                        }
                        .buttonStyle(.plain).foregroundColor(.white)

                        Button(action: { viewModel.togglePlayPause() }) {
                            Image(systemName: viewModel.nowPlayingIsPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain).foregroundColor(.white)

                        Button(action: { viewModel.skipNext() }) {
                            Image(systemName: "forward.fill").font(.system(size: 11))
                        }
                        .buttonStyle(.plain).foregroundColor(.white)
                    }
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(white: 0.25)).frame(height: 2)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(viewModel.nowPlayingElapsedFraction), height: 2)
                }
            }
            .frame(height: 2)
            .cornerRadius(1)
        }
        .onHover { hovering in showControls = hovering }
    }
}
