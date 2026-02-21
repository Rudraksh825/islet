import SwiftUI

struct BuildStatusView: View {
    @ObservedObject var viewModel: IslandViewModel
    @State private var spinAngle: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                buildIcon
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(statusText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(statusColor)

                        if viewModel.buildErrorCount > 0 {
                            Text("\(viewModel.buildErrorCount) errors")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        if viewModel.buildWarningCount > 0 {
                            Text("\(viewModel.buildWarningCount) warnings")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    }
                }
                Spacer()
            }

            if let lastLine = viewModel.buildLastLines.first {
                Text(lastLine.truncated(to: 50))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var buildIcon: some View {
        if viewModel.buildIsRunning {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.orange)
                .rotationEffect(.degrees(spinAngle))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        spinAngle = 360
                    }
                }
        } else if viewModel.buildSuccess == true {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        } else if viewModel.buildSuccess == false {
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        } else {
            Image(systemName: "hammer.fill").foregroundColor(.gray)
        }
    }

    private var statusText: String {
        if viewModel.buildIsRunning { return "Building…" }
        if viewModel.buildSuccess == true { return "Build Succeeded" }
        if viewModel.buildSuccess == false { return "Build Failed" }
        return "Idle"
    }

    private var statusColor: Color {
        if viewModel.buildIsRunning { return .orange }
        if viewModel.buildSuccess == true { return .green }
        if viewModel.buildSuccess == false { return .red }
        return .white
    }
}
