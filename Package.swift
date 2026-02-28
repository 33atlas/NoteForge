// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoteForge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NoteForge",
            targets: ["App"]
        )
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                "Models",
                "Stores",
                "Views"
            ],
            path: "Sources/App"
        ),
        .target(
            name: "Models",
            path: "Sources/Models"
        ),
        .target(
            name: "Stores",
            path: "Sources/Stores",
            dependencies: ["Models"]
        ),
        .target(
            name: "Views",
            path: "Sources/Views",
            dependencies: ["Models", "Stores"]
        )
    ]
)
