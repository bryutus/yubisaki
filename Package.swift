// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "yubisaki",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Yubisaki",
            path: "Sources/Yubisaki",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
