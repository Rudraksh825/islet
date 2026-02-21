import SwiftUI
import AppKit

struct AppSwitcherView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 16) {
            ForEach(viewModel.companionApps.prefix(3), id: \.bundleID) { app in
                Button(action: {
                    NSWorkspace.shared.launchApplication(
                        withBundleIdentifier: app.bundleID,
                        options: [],
                        additionalEventParamDescriptor: nil,
                        launchIdentifier: nil
                    )
                }) {
                    Group {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "app.fill")
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
