// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Droply",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Droply",
            path: "Sources/Droply"
        )
    ]
)
