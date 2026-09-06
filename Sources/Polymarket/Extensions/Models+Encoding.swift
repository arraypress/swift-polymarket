//
//  Models+Encoding.swift
//  Polymarket
//
//  Created by David Sherlock on 2026.
//
//  Canonical encoders: real arrays and real numbers, so the double-encoding
//  stops here.
//

import Foundation

extension Market {
    private enum OutputKeys: String, CodingKey {
        case id, question, description, slug, outcomes, volume, liquidity
        case endDate, closed, active, bestBid, bestAsk, favourite
    }

    /// Writes the flattened shape, not the one the API sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(question, forKey: .question)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(slug, forKey: .slug)
        // A real array, not a string containing one.
        try container.encode(outcomes, forKey: .outcomes)
        try container.encodeIfPresent(volume, forKey: .volume)
        try container.encodeIfPresent(liquidity, forKey: .liquidity)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(closed, forKey: .closed)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(bestBid, forKey: .bestBid)
        try container.encodeIfPresent(bestAsk, forKey: .bestAsk)
        try container.encodeIfPresent(favourite?.name, forKey: .favourite)
    }
}

extension Event {
    private enum OutputKeys: String, CodingKey {
        case id, slug, title, description, volume, liquidity, endDate, closed, active, markets
    }

    /// Writes the flattened shape, not the one the API sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(volume, forKey: .volume)
        try container.encodeIfPresent(liquidity, forKey: .liquidity)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(closed, forKey: .closed)
        try container.encodeIfPresent(active, forKey: .active)
        if !markets.isEmpty { try container.encode(markets, forKey: .markets) }
    }
}
