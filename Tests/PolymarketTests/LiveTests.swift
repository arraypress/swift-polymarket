//
//  LiveTests.swift
//  PolymarketTests
//
//  Created by David Sherlock on 2026.
//
//      PM_LIVE=1 swift test --filter LiveTests
//

import Foundation
import XCTest
@testable import Polymarket

final class LiveTests: XCTestCase {

    private var isEnabled: Bool { ProcessInfo.processInfo.environment["PM_LIVE"] == "1" }

    func testTheGammaAPIAnswersKeylessAndPricesLookLikeProbabilities() async throws {
        try XCTSkipUnless(isEnabled, "set PM_LIVE=1 to run")

        let events = try await Polymarket().events(limit: 5)
        XCTAssertFalse(events.isEmpty)

        let event = try XCTUnwrap(events.first)
        XCTAssertFalse(event.title.isEmpty)
        XCTAssertNotNil(event.volume)
        XCTAssertFalse(event.markets.isEmpty, "an event groups markets")

        let market = try XCTUnwrap(event.markets.first)
        XCTAssertFalse(market.outcomes.isEmpty, "the double-encoded arrays must have decoded")

        for outcome in market.outcomes {
            let price = try XCTUnwrap(outcome.price)
            XCTAssertGreaterThanOrEqual(price, 0, "\(outcome.name) priced \(price)")
            XCTAssertLessThanOrEqual(price, 1, "a probability cannot exceed 1")
        }
        // A two-way market's prices are complementary, within the spread.
        if market.outcomes.count == 2 {
            let total = market.outcomes.compactMap(\.price).reduce(0, +)
            XCTAssertEqual(total, 1.0, accuracy: 0.05, "Yes and No should sum to about 1")
        }
    }
}
