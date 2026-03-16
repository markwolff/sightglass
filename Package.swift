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
        .target(
            name: "SightglassCore",
            dependencies: [
                "Yams",
            ],
            path: "Sources",
            exclude: [
                "Diagram/DiagramExporter.swift",
                "Diagram/DiagramRenderer.swift",
                "Diagram/DiagramView.swift",
                "Diagram/EdgeView.swift",
                "Diagram/LayerColor.swift",
                "Diagram/NodeView.swift",
                "SightglassApp",
                "Views",
            ],
            sources: [
                "Analysis/AnalysisPrompt.swift",
                "Analysis/SpecGenerator.swift",
                "Diagram/DiagramGeometrySnapshot.swift",
                "Diagram/GraphLayout.swift",
                "Models/CodeSpec.swift",
                "Models/EntryPoint.swift",
                "Models/SpecEdge.swift",
                "Models/SpecFlow.swift",
                "Models/SpecLayer.swift",
                "Models/SpecNode.swift",
                "Models/SpecTypeDefinition.swift",
                "Models/ValidationResult.swift",
                "Parser/SpecParser.swift",
            ],
            resources: [
                .copy("Analysis/Resources/prompts"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .executableTarget(
            name: "Sightglass",
            dependencies: ["SightglassUI"],
            path: "Sources",
            exclude: [
                "Analysis",
                "Diagram",
                "Diagram/DiagramGeometrySnapshot.swift",
                "Diagram/GraphLayout.swift",
                "Models",
                "Parser",
                "SightglassApp/AppState.swift",
                "SightglassApp/ContentView.swift",
                "Views",
            ],
            sources: [
                "SightglassApp/SightglassApp.swift",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .target(
            name: "SightglassUI",
            dependencies: ["SightglassCore"],
            path: "Sources",
            exclude: [
                "Analysis",
                "Diagram/DiagramGeometrySnapshot.swift",
                "Diagram/GraphLayout.swift",
                "Models",
                "Parser",
                "SightglassApp/SightglassApp.swift",
            ],
            sources: [
                "Diagram/DiagramExporter.swift",
                "Diagram/DiagramRenderer.swift",
                "Diagram/DiagramView.swift",
                "Diagram/EdgeView.swift",
                "Diagram/LayerColor.swift",
                "Diagram/NodeView.swift",
                "SightglassApp/AppState.swift",
                "SightglassApp/ContentView.swift",
                "Views/DetailPanel.swift",
                "Views/SidebarView.swift",
                "Views/ToolbarView.swift",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .executableTarget(
            name: "SightglassHarness",
            dependencies: ["SightglassCore"],
            path: "Harness",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "SightglassTests",
            dependencies: [
                "SightglassCore",
                "SightglassUI",
            ],
            path: "Tests/SightglassTests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
