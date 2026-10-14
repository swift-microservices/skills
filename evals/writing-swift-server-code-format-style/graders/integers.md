---
type: llm
focus: { source: file, path: Sources/BillingCore/InvoiceText.swift }
---

PASS if all of these hold:
- `amount(cents:)` is built from standard-library integer operations (quotient and remainder, `String(_:)`, explicit zero padding), producing `1234.56`, `0.07`, `-0.05`, and `0.00` for the test inputs, with no grouping.
- `number(_:)` pads to six digits with standard-library operations and does not truncate longer numbers (`INV-000007`, `INV-1234567`).
- Both signatures are unchanged.

FAIL if either function uses `NumberFormatter`, `NSNumber`, `String(format:)`, or a localized number format style, routes amounts through `Double`, or loses the sign of a negative amount between -1 and 0.
Grade only against these criteria; do not fail for issues they do not mention.
