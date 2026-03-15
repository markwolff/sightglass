// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Sightglass",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Sightglass",
            dependencies: [
                "Yams",
            ],
            path: "Sources",
            resources: [
                .copy("../Resources/prompts"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "SightglassTests",
            dependencies: ["Sightglass"],
            path: "Tests/SightglassTests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
