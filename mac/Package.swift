// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CSMMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CSMMac",
            path: "Sources/CSMMac"
        ),
    ]
)
