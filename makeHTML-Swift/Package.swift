// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "makeHTML",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "makeHTML",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: ".",
            exclude: [
                "test-cli.swift",
                "test-batch.swift",
                "test-validation.swift",
                "build",
                "build.sh",
                "snippets",
                "config.json",
                "preview.css"
            ],
            sources: [
                "makeHTMLApp.swift",
                "ContentView.swift",
                "DocxConverter.swift",
                "DocxXMLParser.swift",
                "ConversionLogger.swift"
            ]
        )
    ]
)
