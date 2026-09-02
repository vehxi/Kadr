// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Kadr",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Kadr", targets: ["Kadr"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "Kadr",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Kadr",
            exclude: [
                "Kadr.entitlements",
                "Info.plist",
                "Resources/Assets.xcassets"
            ],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "KadrTests",
            dependencies: ["Kadr"],
            path: "Tests/KadrTests"
        )
    ]
)
