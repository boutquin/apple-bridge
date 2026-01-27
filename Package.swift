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
        .target(name: "Adapters", dependencies: ["Core"]),
        .target(name: "MCPServer", dependencies: ["Core", "Adapters", .product(name: "MCP", package: "swift-sdk")]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "AdapterTests", dependencies: ["Adapters"]),
        .testTarget(name: "MCPServerTests", dependencies: ["MCPServer"]),
        .testTarget(name: "E2ETests", dependencies: ["apple-bridge"])
    ]
)
