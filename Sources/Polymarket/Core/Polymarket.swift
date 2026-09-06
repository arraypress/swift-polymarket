//
//  Polymarket.swift
//  Polymarket
//
//  Created by David Sherlock on 2026.
//
//  Prediction markets, keyless.
//
//  A prediction market prices a share that pays out 1 if an outcome happens,
//  so its price IS the market's probability: "Yes" at 0.62 means the market
//  says 62%. That is the whole reason an agent wants this — one calibrated
//  number for a question with no other numeric answer.
//
//  The Gamma API answers anonymously. Reading needs no key; only trading does,
//  and this library does not trade.
//

import Foundation

/// A keyless client for Polymarket's public data.
public struct Polymarket: Sendable {

    /// How requests are performed — injectable so tests run on recordings.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    /// Sent on every request, so the service can see who is calling.
    public static let defaultUserAgent = "swift-polymarket/0.1 (+https://github.com/arraypress/swift-polymarket)"
    /// The API host. Overridable so tests can point somewhere else.
    public static let defaultHost = "gamma-api.polymarket.com"

    /// How results are ordered.
    public enum Order: String, Sendable, CaseIterable {
        /// Most traded — the markets people actually care about.
        case volume
        /// Deepest book.
        case liquidity
        /// Soonest to resolve.
        case endDate
        /// Newest first.
        case startDate
    }

    /// Sent on every request made by this client.
    public let userAgent: String
    private let host: String
    private let transport: Transport

    public init(userAgent: String = Polymarket.defaultUserAgent,
                host: String = Polymarket.defaultHost,
                transport: Transport? = nil) {
        self.userAgent = userAgent
        self.host = host
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw PolymarketError.malformed("not an HTTP response")
            }
            return (data, http)
        }
    }

    // MARK: - Events

    /// Open events, most traded first by default.
    ///
    /// - Parameters:
    ///   - limit: How many, 1–100.
    ///   - closed: `false` for live questions, `true` for settled ones,
    ///     `nil` for both.
    ///   - order: What "first" means.
    public func events(limit: Int = 20, closed: Bool? = false,
                       order: Order = .volume) async throws -> [Event] {
        let data = try await get("/events", query: [
            "limit": String(min(max(limit, 1), 100)),
            "closed": closed.map(String.init),
            "order": order.rawValue,
            // Ordering without a direction gives ascending, which puts the
            // least-traded markets first — the opposite of what is wanted.
            "ascending": "false",
        ])
        return try decode([Event].self, from: data)
    }

    /// Events matching a search.
    ///
    /// Uses `/public-search`, which is the only endpoint that actually
    /// filters. `/events` accepts a `title_contains` parameter and **silently
    /// ignores it** — the same rows come back for `election` and for
    /// `zzzqqq`, so a search built on it looks like it works and never
    /// filters anything. Verified 2026-09-05.
    public func search(_ query: String, limit: Int = 20, closed: Bool? = false) async throws -> [Event] {
        let data = try await get("/public-search", query: [
            "q": query,
            "limit_per_type": String(min(max(limit, 1), 100)),
            "events_status": closed.map { $0 ? "resolved" : "active" },
        ])
        struct Response: Decodable { let events: [Event]? }
        return try decode(Response.self, from: data).events ?? []
    }

    /// One event by its slug — the last path component of its web URL.
    public func event(slug: String) async throws -> Event {
        let data = try await get("/events", query: ["slug": slug])
        guard let event = try decode([Event].self, from: data).first else {
            throw PolymarketError.notFound("event '\(slug)'")
        }
        return event
    }

    // MARK: - Markets

    /// Individual markets, rather than the events grouping them.
    public func markets(limit: Int = 20, closed: Bool? = false,
                        order: Order = .volume) async throws -> [Market] {
        let data = try await get("/markets", query: [
            "limit": String(min(max(limit, 1), 100)),
            "closed": closed.map(String.init),
            "order": order.rawValue,
            "ascending": "false",
        ])
        return try decode([Market].self, from: data)
    }

    // MARK: - Transport

    private func get(_ path: String, query: [String: String?]) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        let items = query
            .compactMap { key, value -> URLQueryItem? in
                guard let value, !value.isEmpty else { return nil }
                return URLQueryItem(name: key, value: value)
            }
            .sorted { $0.name < $1.name }
        components.queryItems = items.isEmpty ? nil : items

        guard let url = components.url else {
            throw PolymarketError.malformed("could not build a URL for \(path)")
        }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await transport(request)
        switch response.statusCode {
        case 200:
            return data
        case 429:
            let after = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw PolymarketError.rateLimited(retryAfter: after)
        default:
            throw PolymarketError.http(response.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PolymarketError.malformed(error.localizedDescription)
        }
    }
}
