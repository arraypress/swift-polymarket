//
//  PolymarketTests.swift
//  PolymarketTests
//
//  Created by David Sherlock on 2026.
//
//  Offline, on bodies recorded from gamma-api.polymarket.com on 2026-09-05.
//  The double-encoded arrays are the thing worth pinning: get them wrong and
//  every market comes back with no outcomes and no prices, silently.
//

import Foundation
import XCTest
@testable import Polymarket

final class PolymarketTests: XCTestCase {

    private final class Recorder: @unchecked Sendable {
        var requests: [URLRequest] = []
        let body: String
        let status: Int
        init(_ body: String, status: Int = 200) { self.body = body; self.status = status }
        var transport: Polymarket.Transport {
            { [self] request in
                requests.append(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                               httpVersion: nil, headerFields: [:])!
                return (Data(body.utf8), response)
            }
        }
    }

    /// Trimmed verbatim from a real `/events` response — note that `outcomes`
    /// and `outcomePrices` are strings containing arrays, and that the event's
    /// `volume` is a number where the market's is a string.
    private let eventsBody = """
    [ { "id": "30829", "slug": "democratic-presidential-nominee-2028",
        "title": "Democratic Presidential Nominee 2028",
        "volume": 1272486443.6842723, "liquidity": 80590701.43506,
        "endDate": "2028-11-07T00:00:00Z", "closed": false, "active": true,
        "markets": [
          { "id": "559652",
            "question": "Will Gavin Newsom win the 2028 Democratic presidential nomination?",
            "outcomes": "[\\"Yes\\", \\"No\\"]",
            "outcomePrices": "[\\"0.1425\\", \\"0.8575\\"]",
            "volume": "27124125.804421", "liquidity": "308019.94909",
            "endDate": "2028-11-07T00:00:00Z", "closed": false,
            "bestBid": 0.142, "bestAsk": 0.143 },
          { "id": "559653",
            "question": "Will Alexandria Ocasio-Cortez win the 2028 Democratic presidential nomination?",
            "outcomes": "[\\"Yes\\", \\"No\\"]",
            "outcomePrices": "[\\"0.0800\\", \\"0.9200\\"]",
            "volume": "10000000", "closed": false } ] } ]
    """

    // MARK: - The double encoding

    func testOutcomesAndPricesAreArraysWrappedInStringsAndStillDecode() async throws {
        let recorder = Recorder(eventsBody)
        let events = try await Polymarket(transport: recorder.transport).events()

        let market = try XCTUnwrap(events.first?.markets.first)
        XCTAssertEqual(market.outcomes.map(\.name), ["Yes", "No"],
                       "outcomes arrive as a JSON string containing a JSON array")
        XCTAssertEqual(market.outcomes.first?.price ?? 0, 0.1425, accuracy: 0.0001)
        XCTAssertEqual(market.outcomes.last?.price ?? 0, 0.8575, accuracy: 0.0001)
    }

    func testARealArrayWouldAlsoDecodeSoTheDayTheyFixItNothingBreaks() throws {
        let market = try JSONDecoder().decode(Market.self, from: Data("""
        { "id": "1", "question": "q", "outcomes": ["Yes", "No"], "outcomePrices": ["0.6", "0.4"] }
        """.utf8))
        XCTAssertEqual(market.outcomes.map(\.name), ["Yes", "No"])
        XCTAssertEqual(market.outcomes.first?.price ?? 0, 0.6, accuracy: 0.0001)
    }

    func testMissingPricesLeaveOutcomesNamedButUnpriced() throws {
        let market = try JSONDecoder().decode(Market.self, from: Data("""
        { "id": "1", "question": "q", "outcomes": "[\\"Yes\\", \\"No\\"]" }
        """.utf8))
        XCTAssertEqual(market.outcomes.map(\.name), ["Yes", "No"])
        XCTAssertNil(market.outcomes.first?.price, "a named outcome with no price is not a zero price")
    }

    // MARK: - Numbers that change type

    func testVolumeIsANumberOnAnEventAndAStringOnAMarket() async throws {
        let recorder = Recorder(eventsBody)
        let events = try await Polymarket(transport: recorder.transport).events()

        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.volume ?? 0, 1_272_486_443.68, accuracy: 1)
        XCTAssertEqual(event.markets.first?.volume ?? 0, 27_124_125.80, accuracy: 1)
        XCTAssertEqual(event.id, "30829")
    }

    // MARK: - The price is the probability

    func testThePriceIsTheProbability() async throws {
        let recorder = Recorder(eventsBody)
        let events = try await Polymarket(transport: recorder.transport).events()
        let market = try XCTUnwrap(events.first?.markets.first)

        XCTAssertEqual(market.probability(of: "Yes") ?? 0, 0.1425, accuracy: 0.0001)
        XCTAssertEqual(market.probability(of: "yes") ?? 0, 0.1425, accuracy: 0.0001,
                       "the lookup is case-insensitive")
        XCTAssertEqual(market.outcomes.first?.percentage ?? 0, 14.3, accuracy: 0.05)
        XCTAssertNil(market.probability(of: "Maybe"))
        XCTAssertEqual(market.favourite?.name, "No", "the market thinks he will not")
    }

    func testAnEventsFavouriteComparesTheYesSideOfEachMarket() async throws {
        let recorder = Recorder(eventsBody)
        let events = try await Polymarket(transport: recorder.transport).events()
        let favourite = try XCTUnwrap(events.first?.favourite)

        // Newsom at 0.1425 beats Ocasio-Cortez at 0.08 — comparing each
        // market's own favourite would instead pick a "No" at 0.92.
        XCTAssertTrue(favourite.market.question.contains("Newsom"), favourite.market.question)
        XCTAssertEqual(favourite.outcome.name, "Yes")
        XCTAssertEqual(favourite.outcome.price ?? 0, 0.1425, accuracy: 0.0001)
    }

    // MARK: - Requests

    func testOrderingIsDescendingBecauseAscendingPutsTheDeadMarketsFirst() async throws {
        let recorder = Recorder("[]")
        _ = try await Polymarket(transport: recorder.transport).events(limit: 5)

        let url = try XCTUnwrap(recorder.requests.first?.url?.absoluteString)
        XCTAssertTrue(url.contains("order=volume"), url)
        XCTAssertTrue(url.contains("ascending=false"),
                      "without this the least-traded markets come back first")
        XCTAssertTrue(url.contains("closed=false"))
        XCTAssertTrue(url.contains("limit=5"))
    }

    func testTheLimitIsClamped() async throws {
        let recorder = Recorder("[]")
        _ = try await Polymarket(transport: recorder.transport).events(limit: 9_999)
        let url = try XCTUnwrap(recorder.requests.first?.url?.absoluteString)
        XCTAssertTrue(url.contains("limit=100"), url)
    }

    func testAskingForBothOpenAndClosedOmitsTheFilterEntirely() async throws {
        let recorder = Recorder("[]")
        _ = try await Polymarket(transport: recorder.transport).events(closed: nil)
        let url = try XCTUnwrap(recorder.requests.first?.url?.absoluteString)
        XCTAssertFalse(url.contains("closed="), "nil must drop the parameter, not send an empty one")
    }

    /// `/events` accepts `title_contains` and ignores it — the same rows come
    /// back whatever you pass. A search built on that endpoint silently never
    /// filters, which is worse than one that errors.
    func testSearchUsesThePublicSearchEndpointNotTheIgnoredParameter() async throws {
        let recorder = Recorder("""
        { "events": [ { "id": "1", "title": "US Election 2028", "markets": [] } ],
          "pagination": { "hasMore": false } }
        """)
        let events = try await Polymarket(transport: recorder.transport).search("election", limit: 3)

        XCTAssertEqual(events.first?.title, "US Election 2028")
        let url = try XCTUnwrap(recorder.requests.first?.url?.absoluteString)
        XCTAssertTrue(url.contains("/public-search"), url)
        XCTAssertTrue(url.contains("q=election"), url)
        XCTAssertFalse(url.contains("title_contains"),
                       "that parameter is accepted and ignored — using it means never filtering")
    }

    func testSearchAsksForActiveOrResolvedRatherThanTheEventsClosedFlag() async throws {
        let recorder = Recorder(#"{ "events": [] }"#)
        _ = try await Polymarket(transport: recorder.transport).search("x", closed: true)
        let url = try XCTUnwrap(recorder.requests.first?.url?.absoluteString)
        XCTAssertTrue(url.contains("events_status=resolved"), url)
    }

    func testAnUnknownSlugIsNotFound() async {
        let recorder = Recorder("[]")
        do {
            _ = try await Polymarket(transport: recorder.transport).event(slug: "nope")
            XCTFail("an empty list means no such event")
        } catch let error as PolymarketError {
            XCTAssertEqual(error, .notFound("event 'nope'"))
        } catch { XCTFail("unexpected \(error)") }
    }

    func testARateLimitIsItsOwnError() async {
        let recorder = Recorder("", status: 429)
        do {
            _ = try await Polymarket(transport: recorder.transport).events()
            XCTFail("429 must not pass")
        } catch let error as PolymarketError {
            XCTAssertEqual(error, .rateLimited(retryAfter: nil))
        } catch { XCTFail("unexpected \(error)") }
    }

    // MARK: - Encoding

    func testReEmittedJSONCarriesRealArraysAndNumbers() async throws {
        let recorder = Recorder(eventsBody)
        let events = try await Polymarket(transport: recorder.transport).events()
        let market = try XCTUnwrap(events.first?.markets.first)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try JSONEncoder().encode(market)) as? [String: Any]
        )

        let outcomes = try XCTUnwrap(object["outcomes"] as? [[String: Any]])
        XCTAssertEqual(outcomes.count, 2, "a real array, not a string containing one")
        XCTAssertEqual(outcomes.first?["name"] as? String, "Yes")
        XCTAssertNotNil(object["volume"] as? Double, "a real number, not a string")
        XCTAssertNil(object["outcomePrices"], "prices live on their outcome now")
        XCTAssertEqual(object["favourite"] as? String, "No")
    }
}
