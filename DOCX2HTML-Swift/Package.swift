// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "DOCX2HTML",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DOCX2HTML",
            dependencies: [],
            path: "."
        )
    ]
)
