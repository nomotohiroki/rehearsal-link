// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RehearsalLink",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "RehearsalLink",
            dependencies: [],
            path: "Sources/RehearsalLink"
        ),
    ]
)
