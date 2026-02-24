import SwiftUI
import AppKit

// MARK: - NotchIslandView
//
// The panel is full-screen-width × menuBarHeight, sitting at the very top of the screen.
// It is fully transparent — we draw nothing over the menu bar chrome itself.
// When a mode is active we draw content only in the two regions beside the notch:
//   • Left zone:  from panel left edge up to the notch left edge
//   • Right zone: from the notch right edge to the panel right edge
// Nothing is drawn below the menu bar.

struct NotchIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    let geometry: NotchGeometry

    var body: some View {
        GeometryReader { proxy in
            let panelW  = proxy.size.width
            let panelH  = proxy.size.height  // == menuBarHeight

            // Notch edges in panel-local x coordinates
            // (panel starts at screenFrame.minX which is 0 on a single-screen Mac)
            let notchL = geometry.notchRect.minX - geometry.screenFrame.minX
            let notchR = geometry.notchRect.maxX - geometry.screenFrame.minX

            // Available widths beside the notch
            let leftW  = notchL         // full width to the left of the notch
            let rightW = panelW - notchR // full width to the right of the notch

            ZStack(alignment: .topLeading) {
                // Left content zone — right-aligned content hugging the notch
                if viewModel.currentMode != .collapsed && leftW > 0 {
                    LeftContent(viewModel: viewModel)
                        .frame(width: leftW, height: panelH)
                        .offset(x: 0, y: 0)
                }

                // Right content zone — left-aligned content hugging the notch
                if viewModel.currentMode != .collapsed && rightW > 0 {
                    RightContent(viewModel: viewModel)
                        .frame(width: rightW, height: panelH)
                        .offset(x: notchR, y: 0)
                }
            }
            .frame(width: panelW, height: panelH)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentMode)
    }
}

// MARK: - Left content (right-aligned, hugging the notch left edge)

struct LeftContent: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content
                .padding(.trailing, 10)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.currentMode {
        case .nowPlaying:
            HStack(spacing: 6) {
                if let art = viewModel.nowPlayingArt {
                    Image(nsImage: art)
                        .resizable().scaledToFill()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.nowPlayingTrack)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(viewModel.nowPlayingArtist)
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.6))
                        .lineLimit(1)
                }
            }

        case .volume:
            HStack(spacing: 5) {
                Image(systemName: viewModel.volumeIsMuted ? "speaker.slash.fill" : speakerIcon)
                    .font(.system(size: 11))
                    .foregroundColor(viewModel.volumeIsMuted ? .red : .white)
                // Volume bar
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(white: 0.3)).frame(height: 3)
                        Capsule()
                            .fill(viewModel.volumeIsMuted ? Color.red : Color.white)
                            .frame(width: g.size.width * CGFloat(viewModel.volumeIsMuted ? 0 : viewModel.volumeLevel), height: 3)
                    }
                }
                .frame(width: 60, height: 3)
                Text(viewModel.volumeIsMuted ? "—" : "\(Int(viewModel.volumeLevel * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color(white: 0.85))
                    .frame(width: 28, alignment: .trailing)
            }

        case .avConference:
            HStack(spacing: 4) {
                if viewModel.cameraActive {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text("Camera")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
            }

        case .notification(let title, _, let appName, _):
            HStack(spacing: 5) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 0) {
                    Text(appName.isEmpty ? "Notification" : appName)
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.6))
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }

        case .buildStatus:
            HStack(spacing: 5) {
                if viewModel.buildIsRunning {
                    ProgressView().scaleEffect(0.45).frame(width: 12, height: 12).colorScheme(.dark)
                    Text("Building…")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.8))
                } else if let ok = viewModel.buildSuccess {
                    Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(ok ? .green : .red)
                    Text(ok ? "Build succeeded" : "Build failed")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.85))
                }
            }

        case .weather:
            HStack(spacing: 5) {
                Image(systemName: viewModel.weatherSymbol)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                Text("\(Int(viewModel.weatherTemp))°")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                Text(viewModel.weatherCondition)
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.7))
                    .lineLimit(1)
            }

        case .network:
            HStack(spacing: 6) {
                Label(viewModel.networkDownBPS.bwString, systemImage: "arrow.down")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }

        case .airDrop(let name):
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                Text(name)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

        case .systemStats:
            HStack(spacing: 6) {
                Text("CPU \(Int(viewModel.cpuUsage * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

        default:
            EmptyView()
        }
    }

    private var speakerIcon: String {
        if viewModel.volumeLevel == 0 { return "speaker.fill" }
        if viewModel.volumeLevel < 0.33 { return "speaker.wave.1.fill" }
        if viewModel.volumeLevel < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Right content (left-aligned, hugging the notch right edge)

struct RightContent: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 0) {
            content
                .padding(.leading, 10)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.currentMode {
        case .nowPlaying:
            HStack(spacing: 8) {
                Button(action: { viewModel.skipPrevious() }) {
                    Image(systemName: "backward.fill").font(.system(size: 10))
                }.buttonStyle(.plain).foregroundColor(Color(white: 0.7))

                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.nowPlayingIsPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11))
                }.buttonStyle(.plain).foregroundColor(.white)

                Button(action: { viewModel.skipNext() }) {
                    Image(systemName: "forward.fill").font(.system(size: 10))
                }.buttonStyle(.plain).foregroundColor(Color(white: 0.7))
            }

        case .volume:
            EmptyView() // volume bar is already in the left zone

        case .avConference:
            HStack(spacing: 5) {
                if viewModel.micActive {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Text("Mic on")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
            }

        case .notification(_, let body, _, _):
            Text(body)
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.7))
                .lineLimit(1)

        case .buildStatus:
            HStack(spacing: 4) {
                if viewModel.buildErrorCount > 0 {
                    Text("\(viewModel.buildErrorCount)E")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                }
                if viewModel.buildWarningCount > 0 {
                    Text("\(viewModel.buildWarningCount)W")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
            }

        case .network:
            Label(viewModel.networkUpBPS.bwString, systemImage: "arrow.up")
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.7))

        case .systemStats:
            Text("GPU \(Int(viewModel.gpuUsage * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(white: 0.7))

        default:
            EmptyView()
        }
    }
}

// MARK: - Helpers

private extension Double {
    var bwString: String {
        if self < 1_000 { return "0 B/s" }
        if self < 1_000_000 { return String(format: "%.0f KB/s", self / 1_000) }
        return String(format: "%.1f MB/s", self / 1_000_000)
    }
}
