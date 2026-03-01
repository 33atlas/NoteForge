// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoteForge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NoteForge",
            targets: ["App"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.6.0"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0"),
        .package(url: "https://github.com/eonist/FileWatcher.git", from: "0.2.3")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                "Models",
                "Services",
                "Views",
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Ink", package: "Ink"),
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "FileWatcher", package: "FileWatcher")
            ],
            path: "Sources/App"
        ),
        .target(
            name: "Models",
            dependencies: [],
            path: "Sources/Models"
        ),
        .target(
            name: "Services",
            dependencies: [
                "Models",
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "FileWatcher", package: "FileWatcher")
            ],
            path: "Sources/Services"
        ),
        .target(
            name: "Views",
            dependencies: [
                "Models",
                "Services",
                .product(name: "Ink", package: "Ink")
            ],
            path: "Sources/Views"
        )
    ]
)
