//
//  Outcome.swift
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
