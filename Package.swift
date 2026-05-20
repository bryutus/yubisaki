// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "yubisaki",
    defaultLocalization: "ja",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Yubisaki",
            path: "Sources/Yubisaki",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
