---
type: llm
focus: { source: file, path: acme-accounts/Sources/AccountsWorkflows/EmailVerification/EmailVerificationActivities.swift }
---

PASS if email delivery, token issuance, and expiration are separate Activities that delegate to an AccountsCore Activity-service protocol; each Activity's input and output are nested under the Activity container and are Codable and Sendable; and an idempotency key or the registration id from the input drives retries.
FAIL if an Activity takes or returns an AccountsCore entity such as the registration row, a payload lacks Codable, or an Activity mints a fresh UUID for idempotency on each attempt.
