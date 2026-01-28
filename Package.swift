// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "apple-bridge",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "apple-bridge",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                "Core",
                "Adapters",
                "MCPServer"
            ]
        ),
        .target(name: "Core"),
        .target(
            name: "Adapters",
            dependencies: ["Core"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(name: "MCPServer", dependencies: ["Core", "Adapters", .product(name: "MCP", package: "swift-sdk")]),
        .target(
            name: "TestUtilities",
            dependencies: ["Core", "MCPServer"],
            path: "Tests/TestUtilities"
        ),
        .testTarget(name: "CoreTests", dependencies: ["Core", "TestUtilities"]),
        .testTarget(
            name: "AdapterTests",
            dependencies: ["Adapters", "TestUtilities"],
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(name: "MCPServerTests", dependencies: ["MCPServer", "TestUtilities"]),
        .testTarget(name: "E2ETests", dependencies: ["apple-bridge"]),
        .testTarget(name: "SystemTests", dependencies: ["Core", "Adapters"])
    ]
)
