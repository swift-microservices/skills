---
type: llm
focus: { source: file, path: events.md }
---

PASS if the event is a past-tense fact owned by Orders (such as `OrderPlaced`) carrying an event id, the order's identifier, and the facts the consumers need, with no credential and no decision (whether to email or how many points is each consumer's own use case); and the design states that the receipt and the points lag the order (eventually consistent, or a staleness of seconds or more per consumer in a consistency record).

Immutable placement facts a consumer uses to react — line items and totals a receipt renders, the customer's id, the currency — are facts the consumers need, not the entity, even when they are many fields.

FAIL if the event embeds Orders' entity or record type itself (an `order: Order` field, the row as stored) for consumers to read Orders' data from, includes a token or other credential, carries a derived decision (`pointsToAward`, `shouldEmail`), or if consumers read Orders' tables.
