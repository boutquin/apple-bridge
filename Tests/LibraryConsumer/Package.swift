// swift-tools-version: 6.0
import PackageDescription

// A stand-in for an outside package that depends on apple-bridge's library
// products. CI builds it to prove three things the root package cannot prove
// about itself:
//
// 1. The products resolve and build as a dependency (the executable's
//    `unsafeFlags` must not leak into consumers).
// 2. A consumer may have its own targets named `Core` and `Adapters`. SwiftPM
//    requires target names to be unique across the package graph, which is why
//    the library targets carry an `AppleBridge` prefix.
// 3. Contacts + EventKit do not drag in sqlite3 (checked with `otool -L` on
//    the built binary; see .github/workflows/ci.yml).
let package = Package(
    name: "library-consumer",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(name: "apple-bridge", path: "../..")
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "Adapters"),
        .executableTarget(
            name: "library-consumer",
            dependencies: [
                "Core",
                "Adapters",
                .product(name: "AppleBridgeCore", package: "apple-bridge"),
                .product(name: "AppleBridgeContacts", package: "apple-bridge"),
                .product(name: "AppleBridgeEventKit", package: "apple-bridge"),
            ]
        ),
    ]
)
