//
//  Event.swift
//  Polymarket
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A group of related markets — "Democratic Presidential Nominee 2028"
/// holds one market per candidate.
public struct Event: Sendable, Codable, Equatable, Identifiable {
    /// The event id.
    public let id: String
    /// The last path component of its Polymarket page.
    public let slug: String?
    /// The event name.
    public let title: String
    /// The longer explanation shown on the page.
    public let description: String?
    /// Total traded across every market, in USD.
    public let volume: Double?
    /// Resting liquidity across every market, in USD.
    public let liquidity: Double?
    /// When the event resolves.
    public let endDate: Date?
    /// Whether trading has finished.
    public let closed: Bool?
    /// Whether it is currently listed.
    public let active: Bool?
    /// The questions this event is made of.
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
