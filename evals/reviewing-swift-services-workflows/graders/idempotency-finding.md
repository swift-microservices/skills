---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists as a finding (Major or higher), citing Sources/CatalogWorkflows/Reservation/ReservationActivities.swift, that the confirm Activity mints a fresh `UUID()` for its idempotency key on every attempt, so a retry after a successful confirm is not deduplicated, and recommends a key derived from the immutable input (such as the reservation id).
FAIL if the finding is missing, has no file reference, or is ranked Minor.
