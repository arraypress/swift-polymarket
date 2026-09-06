//
//  PolymarketError.swift
//  Polymarket
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong reading prediction markets.
public enum PolymarketError: Error, LocalizedError, Sendable, Equatable {
    case http(Int)
    case rateLimited(retryAfter: Int?)
    case malformed(String)
    case notFound(String)

    /// A one-line reason, for a CLI or a log.
    public var errorDescription: String? {
        switch self {
        case .http(let code): return "Polymarket answered HTTP \(code)"
        case .rateLimited(let after):
            return "Polymarket is rate-limiting" + (after.map { " (retry after \($0)s)" } ?? "")
        case .malformed(let what): return "unexpected response shape: \(what)"
        case .notFound(let what): return "no such \(what)"
        }
    }
}
