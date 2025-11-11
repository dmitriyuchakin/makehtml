// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "makeHTML",
    platforms: [.macOS(.v14)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "makeHTML",
            dependencies: [],
            path: "."
        )
    ]
)
