import SwiftUI

struct SystemStatsView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 16) {
            // CPU bars
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(for: viewModel.cpuUsage))
                            .frame(width: 6, height: 4 + CGFloat(i) * 4)
                            .opacity(Double(i) / 5.0 < viewModel.cpuUsage ? 1.0 : 0.3)
                    }
                }
                Text("CPU \(Int(viewModel.cpuUsage * 100))%")
                    .font(.system(size: 9))
                    .foregroundColor(Color(white: 0.6))
            }

            Divider().frame(height: 36).background(Color(white: 0.3))

            // GPU
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: 6, height: 4 + CGFloat(i) * 4)
                            .opacity(Double(i) / 5.0 < viewModel.gpuUsage ? 1.0 : 0.3)
                    }
                }
                Text("GPU \(Int(viewModel.gpuUsage * 100))%")
                    .font(.system(size: 9))
                    .foregroundColor(Color(white: 0.6))
            }

            Divider().frame(height: 36).background(Color(white: 0.3))

            // Temps
            VStack(alignment: .leading, spacing: 3) {
                if viewModel.cpuTemp > 0 {
                    Label(viewModel.cpuTemp.formattedTemp, systemImage: "cpu")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                if viewModel.gpuTemp > 0 {
                    Label(viewModel.gpuTemp.formattedTemp, systemImage: "square.stack.3d.up")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                if !viewModel.fanRPM.isEmpty {
                    Label(String(format: "%.0f RPM", viewModel.fanRPM[0]), systemImage: "wind")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func barColor(for usage: Double) -> Color {
        switch viewModel.thermalState {
        case .critical: return .red
        case .serious:  return .orange
        case .fair:     return .yellow
        default:        return usage > 0.7 ? .yellow : .green
        }
    }
}
