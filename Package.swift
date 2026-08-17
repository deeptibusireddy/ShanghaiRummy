// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ShanghaiRummySimulation",
    products: [
        .library(
            name: "ShanghaiRummyCore",
            targets: ["ShanghaiRummyCore"]
        ),
        .executable(
            name: "GameSimulationCLI",
            targets: ["GameSimulationCLI"]
        ),
    ],
    targets: [
        .target(
            name: "ShanghaiRummyCore",
            path: "Sources/ShanghaiRummy",
            exclude: [
                "App",
                "Info.plist",
                "Multiplayer",
                "Resources",
                "Scenes",
                "ShanghaiRummy.entitlements",
                "ViewModels",
            ],
            sources: [
                "Models",
                "Rules",
            ]
        ),
        .executableTarget(
            name: "GameSimulationCLI",
            dependencies: ["ShanghaiRummyCore"],
            path: "Simulation"
        ),
    ]
)
