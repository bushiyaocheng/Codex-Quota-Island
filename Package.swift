// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexIsland",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexIsland", targets: ["CodexIsland"])
    ],
    targets: [
        .executableTarget(
            name: "CodexIsland",
            path: "Sources/CodexIsland"
        ),
        .testTarget(
            name: "CodexIslandTests",
            dependencies: ["CodexIsland"],
            path: "Tests/CodexIslandTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
