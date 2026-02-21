// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Islet",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "Islet",
            path: "Islet",
            exclude: [
                "CLI",
                "Info.plist",
                "Islet.entitlements",
            ],
            resources: [
                .copy("menubar_icon.png")
            ],
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"])
            ]
        ),
        .executableTarget(
            name: "island-notify",
            path: "Islet/CLI/island-notify"
        ),
    ]
)
