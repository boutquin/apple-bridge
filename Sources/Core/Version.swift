import Foundation

/// The single source of truth for the apple-bridge version.
///
/// Three places must agree on this number and historically did not:
///
/// 1. This constant — reported to MCP clients in the `initialize` handshake.
/// 2. `Info.plist`'s `CFBundleShortVersionString` / `CFBundleVersion`, embedded
///    into the binary via `-sectcreate __TEXT __info_plist` (see `Package.swift`).
/// 3. The git tag / GitHub release, when one is cut.
///
/// Until 2026-08-05 the constant read `3.0.15` while `Info.plist` still said
/// `1.0.0` — the plist had simply never been updated alongside the source. The
/// drift was invisible because nothing compared them. `VersionTests` now does,
/// so the two cannot diverge again without a red test.
///
/// When releasing: bump `current` here, run the test suite (which enforces the
/// plist match), and tag the release with the same number prefixed by `v`.
public enum AppleBridgeVersion {
    /// The canonical version string, in `MAJOR.MINOR.PATCH` form.
    public static let current = "3.0.15"
}
