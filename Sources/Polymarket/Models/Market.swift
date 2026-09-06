//
//  Market.swift
//  Polymarket
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One tradable question.
public struct Market: Sendable, Codable, Equatable, Identifiable {
    /// The market id.
    public let id: String
    /// The question as asked — "Will X happen by Y?".
    public let question: String
    /// The resolution criteria, in full.
    public let description: String?
    /// The last path component of its Polymarket page.
    public let slug: String?
    /// Outcomes with their prices, in the order the market lists them.
    public let outcomes: [Outcome]
    /// Total traded, in USD.
    public let volume: Double?
    /// Resting liquidity, in USD.
    public let liquidity: Double?
    /// When the question resolves.
    public let endDate: Date?
    /// Whether trading has finished.
    public let closed: Bool?
    /// Whether it is currently listed.
    public let active: Bool?
    /// Best resting bid and ask, when the book is open.
    public let bestBid: Double?
    /// The lowest price anyone is currently selling at.
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
