// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RehearsalLink",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "RehearsalLink",
            dependencies: [],
            path: "Sources/RehearsalLink"
        ),
        .testTarget(
            name: "RehearsalLinkTests",
            dependencies: ["RehearsalLink"],
            path: "Tests/RehearsalLinkTests"
        )
    ]
)
