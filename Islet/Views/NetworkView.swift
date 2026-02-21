import SwiftUI

struct NetworkView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Label(viewModel.networkUpBPS.formattedBandwidth, systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                Label(viewModel.networkDownBPS.formattedBandwidth, systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
            }

            if !viewModel.networkTopProcesses.isEmpty {
                VStack(spacing: 2) {
                    ForEach(viewModel.networkTopProcesses.prefix(3), id: \.name) { proc in
                        HStack {
                            Text(proc.name)
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.7))
                                .lineLimit(1)
                            Spacer()
                            Text(proc.bytesPerSec.formattedBandwidth)
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
