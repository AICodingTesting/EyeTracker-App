// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyeTrackerSuite",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "GazeTrackingKit", targets: ["GazeTrackingKit"]),
        .library(name: "GazeUI", targets: ["GazeUI"]),
        .executable(name: "GazeLabPreviewer", targets: ["GazeLabPreviewer"])
    ],
    targets: [
        .target(
            name: "GazeTrackingKit"
        ),
        .target(
            name: "GazeUI",
            dependencies: [
                "GazeTrackingKit"
            ]
        ),
        .executableTarget(
            name: "GazeLabPreviewer",
            dependencies: ["GazeUI", "GazeTrackingKit"],
            path: "Sources/GazeLabPreviewer"
        ),
        .testTarget(
            name: "GazeTrackingKitTests",
            dependencies: ["GazeTrackingKit"]
        ),
        .testTarget(
            name: "GazeUITests",
            dependencies: ["GazeUI", "GazeTrackingKit"]
        )
    ]
)
