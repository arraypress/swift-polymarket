//
//  Decode.swift
//  Polymarket
//
//  Created by David Sherlock on 2026.
//
//  Two shape traps, absorbed here.
//
//  ONE — **doubly-encoded arrays.** A market's outcomes and their prices
//  arrive as JSON STRINGS that themselves contain JSON arrays:
//
//      "outcomes":      "[\"Yes\", \"No\"]"
//      "outcomePrices": "[\"0.1425\", \"0.8575\"]"
//
//  Decoding `[String]` fails; you get a `String` and have to parse it again.
//
//  TWO — **numbers change type with the endpoint.** An event's `volume` is a
//  JSON number, a market's is a string. Both are read as doubles.
//
//  Verified live against gamma-api.polymarket.com on 2026-09-05.
//

import Foundation

/// Tolerant reads for a service that cannot decide on a type.
enum Decode {

    static func string<K: CodingKey>(_ container: KeyedDecodingContainer<K>?, _ key: K) -> String? {
        guard let container else { return nil }
        return (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil
    }

    static func bool<K: CodingKey>(_ container: KeyedDecodingContainer<K>?, _ key: K) -> Bool? {
        guard let container else { return nil }
        return (try? container.decodeIfPresent(Bool.self, forKey: key)) ?? nil
    }

    /// A double, whether it arrived as a number or a string.
    static func double<K: CodingKey>(_ container: KeyedDecodingContainer<K>?, _ key: K) -> Double? {
        guard let container else { return nil }
        if let number = (try? container.decodeIfPresent(Double.self, forKey: key)) ?? nil { return number }
        guard let text = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil else { return nil }
        return Double(text)
    }

    /// An identifier, which is a string on some endpoints and a number on others.
    static func identifier<K: CodingKey>(_ container: KeyedDecodingContainer<K>?, _ key: K) -> String? {
        guard let container else { return nil }
        if let text = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil { return text }
        guard let number = (try? container.decodeIfPresent(Int.self, forKey: key)) ?? nil else { return nil }
        return String(number)
    }

    static func value<T: Decodable, K: CodingKey>(
        _ type: T.Type, _ container: KeyedDecodingContainer<K>?, _ key: K
    ) -> T? {
        guard let container else { return nil }
        return (try? container.decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    /// Reads a field that is a JSON array wrapped in a JSON string.
    ///
    /// Accepts a real array too, so the day the service stops double-encoding
    /// this keeps working rather than starts failing.
    static func nestedStrings<K: CodingKey>(_ container: KeyedDecodingContainer<K>?, _ key: K) -> [String] {
        guard let container else { return [] }
        if let direct = (try? container.decodeIfPresent([String].self, forKey: key)) ?? nil { return direct }
        guard let text = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil,
              let data = text.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return parsed
    }
}
