import Foundation
import Core
import Adapters

/// Mock implementation of `MailAdapterProtocol` for testing.
///
/// Provides stubbed data and tracks method calls for verification in tests.
/// All methods are actor-isolated for thread safety.
public actor MockMailAdapter: MailAdapterProtocol {

    // MARK: - Stub Data

    /// Stubbed emails to return.
    private var stubEmails: [EmailData] = []

    /// Error to throw (if set) for testing error scenarios.
    private var errorToThrow: (any Error)?

    // MARK: - Tracking

    /// Tracks fetch unread requests.
    private var fetchUnreadRequests: [(limit: Int, includeBody: Bool)] = []

    /// Tracks search requests.
    private var searchRequests: [(query: String, limit: Int, includeBody: Bool)] = []

    /// Tracks sent emails.
    private var sentEmails: [(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?)] = []

    /// Tracks compose requests.
    private var composeRequests: [(to: [String]?, subject: String?, body: String?)] = []

    // MARK: - Initialization

    /// Creates a new mock mail adapter.
    public init() {}

    // MARK: - Setup Methods

    /// Sets stubbed emails for testing.
    public func setStubEmails(_ emails: [EmailData]) {
        self.stubEmails = emails
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    // MARK: - Verification Methods

    /// Gets the fetch unread requests for verification.
    public func getFetchUnreadRequests() -> [(limit: Int, includeBody: Bool)] {
        return fetchUnreadRequests
    }

    /// Gets the search requests for verification.
    public func getSearchRequests() -> [(query: String, limit: Int, includeBody: Bool)] {
        return searchRequests
    }

    /// Gets the sent emails for verification.
    public func getSentEmails() -> [(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?)] {
        return sentEmails
    }

    /// Gets the compose requests for verification.
    public func getComposeRequests() -> [(to: [String]?, subject: String?, body: String?)] {
        return composeRequests
    }

    // MARK: - MailAdapterProtocol

    public func fetchUnread(limit: Int, includeBody: Bool) async throws -> [EmailData] {
        if let error = errorToThrow { throw error }
        fetchUnreadRequests.append((limit: limit, includeBody: includeBody))

        let unread = stubEmails.filter { $0.isUnread }
        let results = includeBody ? unread : unread.map { email in
            EmailData(
                id: email.id,
                subject: email.subject,
                from: email.from,
                to: email.to,
                date: email.date,
                body: nil,
                mailbox: email.mailbox,
                isUnread: email.isUnread
            )
        }

        return Array(results.prefix(limit))
    }

    public func searchEmails(query: String, limit: Int, includeBody: Bool) async throws -> [EmailData] {
        if let error = errorToThrow { throw error }
        searchRequests.append((query: query, limit: limit, includeBody: includeBody))

        // Filter by query in subject or body
        let filtered = stubEmails.filter { email in
            email.subject.localizedCaseInsensitiveContains(query) ||
            (email.body?.localizedCaseInsensitiveContains(query) ?? false)
        }

        let results = includeBody ? filtered : filtered.map { email in
            EmailData(
                id: email.id,
                subject: email.subject,
                from: email.from,
                to: email.to,
                date: email.date,
                body: nil,
                mailbox: email.mailbox,
                isUnread: email.isUnread
            )
        }

        return Array(results.prefix(limit))
    }

    public func sendEmail(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?) async throws {
        if let error = errorToThrow { throw error }
        sentEmails.append((to: to, subject: subject, body: body, cc: cc, bcc: bcc))
    }

    public func composeEmail(to: [String]?, subject: String?, body: String?) async throws {
        if let error = errorToThrow { throw error }
        composeRequests.append((to: to, subject: subject, body: body))
    }
}
