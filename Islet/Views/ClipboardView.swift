import SwiftUI

struct ClipboardView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "clipboard.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                Text("Clipboard (\(viewModel.clipboardCount))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(viewModel.clipboardItems) { item in
                        HStack {
                            itemIcon(for: item)
                            Text(item.preview)
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.8))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(white: 0.12))
                        .cornerRadius(6)
                        .onTapGesture {
                            viewModel.selectClipboardItem(item)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func itemIcon(for item: ClipboardItem) -> some View {
        switch item {
        case .text:
            Image(systemName: "text.alignleft").font(.system(size: 9)).foregroundColor(Color(white: 0.5))
        case .url:
            Image(systemName: "link").font(.system(size: 9)).foregroundColor(.blue)
        case .file:
            Image(systemName: "doc.fill").font(.system(size: 9)).foregroundColor(.orange)
        case .image:
            Image(systemName: "photo.fill").font(.system(size: 9)).foregroundColor(.purple)
        }
    }
}
