import MCP

extension Tool.Content {
    /// Plain text result content with no `annotations` / `_meta`.
    ///
    /// The MCP swift-sdk 0.12 upgrade gave `.text` associated values
    /// (`text:`, `annotations:`, `_meta:`) and deprecated the one-argument
    /// `.text(_:)` factory. This convenience restores the common
    /// "just some text" construction at the call sites without repeating the
    /// `annotations: nil, _meta: nil` boilerplate.
    public static func plain(_ text: String) -> Tool.Content {
        .text(text: text, annotations: nil, _meta: nil)
    }
}
