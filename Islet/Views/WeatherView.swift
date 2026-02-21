import SwiftUI

struct WeatherView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.weatherSymbol)
                .font(.system(size: 28))
                .foregroundColor(.white)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f°C", viewModel.weatherTemp))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(viewModel.weatherCondition)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.6))
            }

            if viewModel.weatherPrecipProb > 20 {
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("\(viewModel.weatherPrecipProb)%")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
