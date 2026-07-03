// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "yubisaki",
    defaultLocalization: "ja",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Yubisaki",
            path: "Sources/Yubisaki",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [.linkedFramework("ServiceManagement")]
        ),
        .testTarget(
            name: "YubisakiTests",
            dependencies: ["Yubisaki"],
            path: "Tests/YubisakiTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
