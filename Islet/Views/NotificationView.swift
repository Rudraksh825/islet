import SwiftUI
import AppKit

struct NotificationView: View {
    let title: String
    let notificationBody: String
    let appName: String
    let appIcon: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(appName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(white: 0.5))
                    Spacer()
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(notificationBody)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.7))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
