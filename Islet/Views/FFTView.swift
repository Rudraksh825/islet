import SwiftUI

struct FFTView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<viewModel.fftBins.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: i))
                    .frame(width: 4, height: max(2, CGFloat(viewModel.fftBins[i]) * 40))
                    .animation(.linear(duration: 0.05), value: viewModel.fftBins[i])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func barColor(for index: Int) -> Color {
        let fraction = Double(index) / Double(viewModel.fftBins.count)
        if fraction < 0.33 { return .purple }
        if fraction < 0.66 { return .blue }
        return .cyan
    }
}
