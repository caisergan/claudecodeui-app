// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClaudeCodeUI",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ClaudeCodeUI",
            targets: ["ClaudeCodeUI"]
        )
    ],
    targets: [
        .target(
            name: "ClaudeCodeUI",
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "ClaudeCodeUITests",
            dependencies: ["ClaudeCodeUI"],
            path: "Tests/UnitTests"
        )
    ]
)
