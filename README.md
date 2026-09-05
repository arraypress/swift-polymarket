# swift-polymarket

Prediction markets as probabilities. No key.

```swift
import Polymarket

let markets = try await Polymarket().events(limit: 10)
markets[0].title                          // "Fed decision in December"
markets[0].favourite?.outcome.percentage  // 62.0
```

## Why an agent wants this

A prediction market prices a share that pays out 1 if an outcome happens — so
**the price is the probability**. "Yes" at 0.62 means the market says 62%.

That makes it one of the few sources that answers an unanswerable question with
a calibrated number: how likely is this, according to people with money on it.
No model, no vibes, no key.

## Use

```swift
let poly = Polymarket()

try await poly.events()                          // open, most traded first
try await poly.events(closed: true)              // settled questions
try await poly.search("election")
try await poly.event(slug: "fed-decision-in-december")
try await poly.markets(order: .endDate)          // resolving soonest
```

Reading the odds:

```swift
market.probability(of: "Yes")   // 0.1425
market.outcomes.first?.percentage  // 14.3
market.favourite                // the outcome the market backs
event.favourite                 // across all of an event's markets
```

An **event** groups related **markets** — "Democratic Presidential Nominee 2028"
holds one market per candidate, each a Yes/No. `event.favourite` compares the
*Yes* side of each, because comparing each market's own favourite would just
find the biggest "No".

## Two shape traps, both handled

**Arrays arrive doubly encoded.** Outcomes and prices are JSON *strings* that
contain JSON arrays:

```json
"outcomes":      "[\"Yes\", \"No\"]",
"outcomePrices": "[\"0.1425\", \"0.8575\"]"
```

Decoding `[String]` fails; you get a `String` and have to parse it again. Miss
this and every market comes back with no outcomes and no prices — silently, with
no error. A real array decodes too, so the day they fix it nothing breaks.

**Numbers change type with the endpoint.** An event's `volume` is a JSON number;
a market's is a string. Both read as `Double`, and both encode back out as real
numbers.

Verified live 2026-09-05.

## Ordering

`ascending=false` is sent explicitly. Without it the API orders ascending, so
`order: .volume` returns the *least*-traded markets first — the exact opposite of
what anyone means.

## No key, and no trading

The Gamma API answers anonymously; only trading needs credentials, and this
library does not trade. It reads.

## Tested

13 tests. Twelve offline on recorded bodies — including the double encoding, the
type-shifting numbers and the ordering flag. One live check asserts that prices
are real probabilities: each between 0 and 1, and a two-way market's Yes and No
summing to about 1. Passed 2026-09-05.

```console
$ PM_LIVE=1 swift test --filter LiveTests
```

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-polymarket.git", from: "0.1.0")
```

## Licence

MIT
