import SwiftUI
import AppKit

// MARK: - NotchIslandView
// The panel is a transparent rectangle that spans the notch zone.
// This view draws content AROUND the notch dead-zone:
//   • Left lobe  — to the left of the notch, in the menu bar stripe
//   • Right lobe — to the right of the notch, in the menu bar stripe
//   • Below zone — drops below the notch for expanded content
// The notch itself is never drawn over.

struct NotchIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    let geometry: NotchGeometry

    var body: some View {
        GeometryReader { proxy in
            let panelW = proxy.size.width
            let menuH  = geometry.menuBarHeight
            // Within the panel coordinate system (origin = bottom-left of panel):
            // The notch occupies the top menuH, centred horizontally.
            // notchLeft and notchRight are in panel-local coords.
            let notchLeft  = (panelW - geometry.notchRect.width) / 2
            let notchRight = notchLeft + geometry.notchRect.width

            ZStack(alignment: .topLeading) {
                // ── Left lobe (sits left of notch in menu bar row) ──────────
                LeftLobeView(viewModel: viewModel, geometry: geometry)
                    .frame(width: notchLeft, height: menuH)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // ── Right lobe (sits right of notch in menu bar row) ─────────
                RightLobeView(viewModel: viewModel, geometry: geometry)
                    .frame(width: panelW - notchRight, height: menuH)
                    .offset(x: notchRight, y: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // ── Below-notch expansion (drops below the menu bar row) ─────
                if viewModel.currentMode != .collapsed {
                    BelowNotchView(viewModel: viewModel)
                        .frame(width: panelW, height: proxy.size.height - menuH)
                        .offset(x: 0, y: menuH)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(width: panelW, height: proxy.size.height, alignment: .topLeading)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.currentMode)
    }
}

// MARK: - Left Lobe
// Shows compact, left-biased info (album art, camera dot, etc.)
struct LeftLobeView: View {
    @ObservedObject var viewModel: IslandViewModel
    let geometry: NotchGeometry

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            content
                .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.currentMode {
        case .nowPlaying:
            NowPlayingLobeView(viewModel: viewModel, side: .left)
        case .avConference:
            AVConferenceLobe(viewModel: viewModel, side: .left)
        case .volume:
            VolumeLobeView(viewModel: viewModel)
        case .buildStatus:
            BuildStatusLobe(viewModel: viewModel, side: .left)
        default:
            EmptyView()
        }
    }
}

// MARK: - Right Lobe
// Shows compact, right-biased info (time, battery, playback controls, etc.)
struct RightLobeView: View {
    @ObservedObject var viewModel: IslandViewModel
    let geometry: NotchGeometry

    var body: some View {
        HStack(spacing: 0) {
            content
                .padding(.leading, 10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.currentMode {
        case .nowPlaying:
            NowPlayingLobeView(viewModel: viewModel, side: .right)
        case .avConference:
            AVConferenceLobe(viewModel: viewModel, side: .right)
        case .volume:
            // Right lobe unused for volume — volume bar is in the below zone
            EmptyView()
        case .buildStatus:
            BuildStatusLobe(viewModel: viewModel, side: .right)
        default:
            EmptyView()
        }
    }
}

// MARK: - Below-notch expansion
// This is the "dropped pill" that appears below the menu bar and contains rich content.
struct BelowNotchView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack {
            // The pill drops from the centre, hugging below the notch
            expandedContent
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black)
                )
                // Attach to top edge, centred
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 2)

            Spacer()
        }
        .padding(.horizontal, 40) // keep it narrower than the panel
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch viewModel.currentMode {
        case .nowPlaying:
            NowPlayingView(viewModel: viewModel)
        case .volume:
            VolumeView(viewModel: viewModel)
        case .weather:
            WeatherView(viewModel: viewModel)
        case .notification(let title, let body, let appName, let icon):
            NotificationView(title: title, notificationBody: body, appName: appName, appIcon: icon)
        case .systemStats:
            SystemStatsView(viewModel: viewModel)
        case .network:
            NetworkView(viewModel: viewModel)
        case .clipboard:
            ClipboardView(viewModel: viewModel)
        case .fileRecovery(let name, let trashURL, let origURL):
            TrashRecoveryView(fileName: name, trashURL: trashURL, originalURL: origURL, viewModel: viewModel)
        case .colorSampler(let color):
            ColorSamplerView(color: color)
        case .avConference:
            AVConferenceView(viewModel: viewModel)
        case .buildStatus:
            BuildStatusView(viewModel: viewModel)
        case .stdout:
            StdoutView(viewModel: viewModel)
        case .airDrop(let name):
            AirDropView(fileName: name)
        case .collapsed:
            EmptyView()
        }
    }
}

// MARK: - Lobe content components

enum LobeSide { case left, right }

struct NowPlayingLobeView: View {
    @ObservedObject var viewModel: IslandViewModel
    let side: LobeSide

    var body: some View {
        if side == .left {
            // Album art thumbnail
            Group {
                if let art = viewModel.nowPlayingArt {
                    Image(nsImage: art)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                }
            }
        } else {
            // Playback state indicator
            Image(systemName: viewModel.nowPlayingIsPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.75))
        }
    }
}

struct AVConferenceLobe: View {
    @ObservedObject var viewModel: IslandViewModel
    let side: LobeSide

    var body: some View {
        if side == .left {
            // Camera dot
            if viewModel.cameraActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        } else {
            // Mic indicator
            if viewModel.micActive {
                Image(systemName: viewModel.micActive ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
            }
        }
    }
}

struct VolumeLobeView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.volumeIsMuted ? "speaker.slash.fill" : speakerSymbol)
                .font(.system(size: 11))
                .foregroundColor(viewModel.volumeIsMuted ? .red : .white)
            Text(viewModel.volumeIsMuted ? "Muted" : "\(Int(viewModel.volumeLevel * 100))%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Color(white: 0.85))
        }
    }

    private var speakerSymbol: String {
        if viewModel.volumeLevel == 0 { return "speaker.fill" }
        if viewModel.volumeLevel < 0.33 { return "speaker.wave.1.fill" }
        if viewModel.volumeLevel < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

struct BuildStatusLobe: View {
    @ObservedObject var viewModel: IslandViewModel
    let side: LobeSide

    var body: some View {
        if side == .left {
            if viewModel.buildIsRunning {
                // Spinning indicator
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
                    .colorScheme(.dark)
            } else if let success = viewModel.buildSuccess {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(success ? .green : .red)
            }
        } else {
            if viewModel.buildErrorCount > 0 {
                Text("\(viewModel.buildErrorCount)E")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            } else if viewModel.buildWarningCount > 0 {
                Text("\(viewModel.buildWarningCount)W")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }
        }
    }
}
