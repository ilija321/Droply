// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DropoverClone",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DropoverClone",
            path: "Sources/DropoverClone"
        )
    ]
)
