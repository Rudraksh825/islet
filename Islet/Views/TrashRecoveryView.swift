import SwiftUI

struct TrashRecoveryView: View {
    let fileName: String
    let trashURL: URL
    let originalURL: URL
    @ObservedObject var viewModel: IslandViewModel
    @State private var countdown: Int

    init(fileName: String, trashURL: URL, originalURL: URL, viewModel: IslandViewModel) {
        self.fileName = fileName
        self.trashURL = trashURL
        self.originalURL = originalURL
        self.viewModel = viewModel
        _countdown = State(initialValue: SystemConfig.shared.fileRecoveryWindowSeconds)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color(white: 0.3), lineWidth: 2)
                    .frame(width: 36, height: 36)

                // Countdown arc
                Circle()
                    .trim(from: 0, to: CGFloat(countdown) / CGFloat(SystemConfig.shared.fileRecoveryWindowSeconds))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text("\(countdown)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Deleted")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.5))
                Text(fileName.truncated(to: 20))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            Button("Restore") {
                viewModel.restoreFile(trashURL: trashURL, originalURL: originalURL)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.orange)
            .cornerRadius(8)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                countdown -= 1
                if countdown <= 0 { timer.invalidate() }
            }
        }
    }
}
