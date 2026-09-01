// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WritingApp",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "WritingApp", targets: ["WritingApp"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-markdown.git",
            exact: "0.8.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "WritingApp",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            exclude: ["Info.plist"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "WritingAppTests",
            dependencies: ["WritingApp"]
        ),
    ]
)
