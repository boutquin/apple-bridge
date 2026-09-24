// swift-tools-version: 6.0
import PackageDescription

// Library products are a public API: a breaking change to any public type in
// them needs a major version bump. Only the surfaces an outside consumer has
// asked for are products; the other adapter targets stay internal to the
// executable until someone needs them.
//
// Every target a library product builds carries an `AppleBridge` prefix:
// SwiftPM requires target names to be unique across a consumer's whole package
// graph, so a bare `Core` collides with any consumer that has its own.
let package = Package(
    name: "apple-bridge",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AppleBridgeCore", targets: ["AppleBridgeCore"]),
        .library(name: "AppleBridgeContacts", targets: ["AppleBridgeContacts"]),
        .library(name: "AppleBridgeEventKit", targets: ["AppleBridgeEventKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", .upToNextMinor(from: "0.12.1"))
    ],
    targets: [
        .executableTarget(
            name: "apple-bridge",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                "AppleBridgeCore",
                "AppleBridgeContacts",
                "AppleBridgeEventKit",
                "AppleBridgeMail",
                "AppleBridgeMaps",
                "AppleBridgeMessages",
                "AppleBridgeNotes",
                "MCPServer"
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        ),

        // Models, errors, and service protocols. No framework dependencies.
        .target(name: "AppleBridgeCore", path: "Sources/Core"),

        // Shared infrastructure for the adapters.
        .target(
            name: "AppleBridgeAppleScript",
            dependencies: ["AppleBridgeCore"],
            path: "Sources/Adapters/AppleScriptAdapter"
        ),
        .target(
            name: "AppleBridgeSQLite",
            dependencies: ["AppleBridgeCore"],
            path: "Sources/Adapters/SQLiteAdapter",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),

        // One target per surface, so a consumer links only what it uses.
        .target(
            name: "AppleBridgeContacts",
            dependencies: ["AppleBridgeCore", "AppleBridgeAppleScript"],
            path: "Sources/Adapters/ContactsAdapter"
        ),
        .target(
            name: "AppleBridgeEventKit",
            dependencies: ["AppleBridgeCore"],
            path: "Sources/Adapters/EventKitAdapter"
        ),
        .target(
            name: "AppleBridgeMail",
            dependencies: ["AppleBridgeCore", "AppleBridgeAppleScript"],
            path: "Sources/Adapters/MailAdapter"
        ),
        .target(
            name: "AppleBridgeMaps",
            dependencies: ["AppleBridgeCore"],
            path: "Sources/Adapters/MapsAdapter"
        ),
        .target(
            name: "AppleBridgeMessages",
            dependencies: ["AppleBridgeCore", "AppleBridgeAppleScript", "AppleBridgeSQLite"],
            path: "Sources/Adapters/MessagesAdapter",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "AppleBridgeNotes",
            dependencies: ["AppleBridgeCore", "AppleBridgeAppleScript", "AppleBridgeSQLite"],
            path: "Sources/Adapters/NotesAdapter",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),

        .target(name: "MCPServer", dependencies: ["AppleBridgeCore", .product(name: "MCP", package: "swift-sdk")]),
        .target(
            name: "TestUtilities",
            dependencies: ["AppleBridgeCore", "MCPServer"],
            path: "Tests/TestUtilities"
        ),
        .testTarget(name: "CoreTests", dependencies: ["AppleBridgeCore", "TestUtilities"]),
        .testTarget(
            name: "AdapterTests",
            dependencies: [
                "AppleBridgeAppleScript",
                "AppleBridgeContacts",
                "AppleBridgeEventKit",
                "AppleBridgeMail",
                "AppleBridgeMaps",
                "AppleBridgeMessages",
                "AppleBridgeNotes",
                "AppleBridgeSQLite",
                "TestUtilities"
            ],
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(name: "MCPServerTests", dependencies: ["MCPServer", "TestUtilities"]),
        .testTarget(name: "E2ETests", dependencies: ["apple-bridge", "TestUtilities"]),
        .testTarget(
            name: "SystemTests",
            dependencies: [
                "AppleBridgeCore",
                "AppleBridgeAppleScript",
                "AppleBridgeContacts",
                "AppleBridgeEventKit",
                "AppleBridgeMail",
                "AppleBridgeMaps",
                "AppleBridgeMessages",
                "AppleBridgeNotes",
                "AppleBridgeSQLite",
                "TestUtilities"
            ]
        )
    ]
)
