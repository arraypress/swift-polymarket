//
//  Models.swift
//  Polymarket
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One outcome of a market, and what the market thinks of it.
public struct Outcome: Sendable, Codable, Equatable {
    /// `Yes`, `No`, or a candidate's name on a multi-way market.
    public let name: String
    /// The share price, 0–1. **This is the implied probability** — a share
    /// pays out 1 if the outcome happens, so its price is the market's odds.
    public let price: Double?

    public init(name: String, price: Double?) {
        self.name = name
        self.price = price
    }

    /// The price as a percentage, rounded — `14.3%`.
    public var percentage: Double? { price.map { ($0 * 1000).rounded() / 10 } }
}

/// One tradable question.
public struct Market: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    /// The question as asked — "Will X happen by Y?".
    public let question: String
    public let description: String?
    public let slug: String?
    /// Outcomes with their prices, in the order the market lists them.
    public let outcomes: [Outcome]
    /// Total traded, in USD.
    public let volume: Double?
    /// Resting liquidity, in USD.
    public let liquidity: Double?
    public let endDate: Date?
    public let closed: Bool?
    public let active: Bool?
    /// Best resting bid and ask, when the book is open.
    public let bestBid: Double?
    public let bestAsk: Double?

    /// The price of a named outcome — `market.probability(of: "Yes")`.
    public func probability(of outcome: String) -> Double? {
        outcomes.first { $0.name.caseInsensitiveCompare(outcome) == .orderedSame }?.price
    }

    /// The outcome the market currently favours.
    public var favourite: Outcome? {
        outcomes.max { ($0.price ?? 0) < ($1.price ?? 0) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, question, description, slug, outcomes, outcomePrices
        case volume, liquidity, endDate, closed, active, bestBid, bestAsk
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = Decode.identifier(container, .id) ?? ""
        self.question = Decode.string(container, .question) ?? ""
        self.description = Decode.string(container, .description)
        self.slug = Decode.string(container, .slug)

        // Both of these are JSON arrays wrapped in JSON strings.
        let names = Decode.nestedStrings(container, .outcomes)
        let prices = Decode.nestedStrings(container, .outcomePrices).map(Double.init)
        self.outcomes = names.enumerated().map { index, name in
            Outcome(name: name, price: index < prices.count ? prices[index] : nil)
        }

        self.volume = Decode.double(container, .volume)
        self.liquidity = Decode.double(container, .liquidity)
        self.endDate = Timestamps.parse(Decode.string(container, .endDate))
        self.closed = Decode.bool(container, .closed)
        self.active = Decode.bool(container, .active)
        self.bestBid = Decode.double(container, .bestBid)
        self.bestAsk = Decode.double(container, .bestAsk)
    }

    public init(id: String, question: String, outcomes: [Outcome],
                description: String? = nil, slug: String? = nil,
                volume: Double? = nil, liquidity: Double? = nil, endDate: Date? = nil,
                closed: Bool? = nil, active: Bool? = nil,
                bestBid: Double? = nil, bestAsk: Double? = nil) {
        self.id = id
        self.question = question
        self.description = description
        self.slug = slug
        self.outcomes = outcomes
        self.volume = volume
        self.liquidity = liquidity
        self.endDate = endDate
        self.closed = closed
        self.active = active
        self.bestBid = bestBid
        self.bestAsk = bestAsk
    }
}

/// A group of related markets — "Democratic Presidential Nominee 2028"
/// holds one market per candidate.
public struct Event: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let slug: String?
    public let title: String
    public let description: String?
    public let volume: Double?
    public let liquidity: Double?
    public let endDate: Date?
    public let closed: Bool?
    public let active: Bool?
    public let markets: [Market]

    /// The market this event most favours, across all its questions.
    public var favourite: (market: Market, outcome: Outcome)? {
        var best: (Market, Outcome)?
        for market in markets {
            // On a multi-market event each market is one candidate's "Yes",
            // so comparing the Yes side is what ranks them.
            guard let yes = market.outcomes.first(where: { $0.name.caseInsensitiveCompare("Yes") == .orderedSame })
                    ?? market.favourite
            else { continue }
            if (yes.price ?? 0) > (best?.1.price ?? 0) { best = (market, yes) }
        }
        return best.map { (market: $0.0, outcome: $0.1) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, slug, title, description, volume, liquidity, endDate, closed, active, markets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = Decode.identifier(container, .id) ?? ""
        self.slug = Decode.string(container, .slug)
        self.title = Decode.string(container, .title) ?? ""
        self.description = Decode.string(container, .description)
        // A number here, a string on a market — read both ways.
        self.volume = Decode.double(container, .volume)
        self.liquidity = Decode.double(container, .liquidity)
        self.endDate = Timestamps.parse(Decode.string(container, .endDate))
        self.closed = Decode.bool(container, .closed)
        self.active = Decode.bool(container, .active)
        self.markets = Decode.value([Market].self, container, .markets) ?? []
    }
}

/// Timestamp parsing.
enum Timestamps {
    private static let plain = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        return (try? plain.parse(text)) ?? (try? fractional.parse(text))
    }
}
