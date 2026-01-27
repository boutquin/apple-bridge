import Foundation
import Core

/// Mock implementation of `MailService` for testing.
public actor MockMailService: MailService {

    /// Stubbed emails to return from read operations.
    public var stubEmails: [Email] = []

    /// Tracks emails that have been sent.
    public var sentEmails: [(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?)] = []

    /// Tracks compose requests.
    public var composeRequests: [(to: [String]?, subject: String?, body: String?)] = []

    /// Error to throw (if set) for testing error scenarios.
    public var errorToThrow: (any Error)?

    /// Creates a new mock mail service.
    public init() {}

    /// Sets stubbed emails for testing.
    public func setStubEmails(_ emails: [Email]) {
        self.stubEmails = emails
    }

    /// Sets an error to throw on subsequent operations.
    public func setError(_ error: (any Error)?) {
        self.errorToThrow = error
    }

    /// Gets sent emails for verification.
    public func getSentEmails() -> [(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?)] {
        return sentEmails
    }

    /// Gets compose requests for verification.
    public func getComposeRequests() -> [(to: [String]?, subject: String?, body: String?)] {
        return composeRequests
    }

    public func unread(limit: Int, includeBody: Bool) async throws -> [Email] {
        if let error = errorToThrow { throw error }

        let filtered = stubEmails.filter { $0.isUnread }

        // Optionally strip body
        let results = includeBody ? filtered : filtered.map { email in
            Email(id: email.id, subject: email.subject, from: email.from, to: email.to,
                  date: email.date, body: nil, mailbox: email.mailbox, isUnread: email.isUnread)
        }

        return Array(results.prefix(limit))
    }

    public func search(query: String, limit: Int, includeBody: Bool) async throws -> [Email] {
        if let error = errorToThrow { throw error }

        let filtered = stubEmails.filter { email in
            email.subject.localizedCaseInsensitiveContains(query) ||
            email.from.localizedCaseInsensitiveContains(query) ||
            (email.body?.localizedCaseInsensitiveContains(query) ?? false)
        }

        // Optionally strip body
        let results = includeBody ? filtered : filtered.map { email in
            Email(id: email.id, subject: email.subject, from: email.from, to: email.to,
                  date: email.date, body: nil, mailbox: email.mailbox, isUnread: email.isUnread)
        }

        return Array(results.prefix(limit))
    }

    public func send(to: [String], subject: String, body: String, cc: [String]?, bcc: [String]?) async throws {
        if let error = errorToThrow { throw error }
        sentEmails.append((to: to, subject: subject, body: body, cc: cc, bcc: bcc))
    }

    public func compose(to: [String]?, subject: String?, body: String?) async throws {
        if let error = errorToThrow { throw error }
        composeRequests.append((to: to, subject: subject, body: body))
    }
}
