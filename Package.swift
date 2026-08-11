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
    targets: [
        .executableTarget(
            name: "Kadr",
            path: "Kadr",
            exclude: [
                "Kadr.entitlements",
                "Resources/Assets.xcassets"
            ],
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        )
    ]
)
