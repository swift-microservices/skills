---
type: llm
focus: { source: file, path: Sources/CatalogWebhooks/WebhookNotifier.swift }
---

PASS if all of these hold:
- A 2xx status records the item as delivered; a 4xx gives up without a retry and logs it.
- A 5xx status or a thrown transport error is retried exactly once, then logged and given up.
- The notifier consults the delivery log so an item already delivered or in flight is not posted again, and a failed delivery is not recorded as delivered.

FAIL if the file is missing or a stub, a 4xx is retried, a 5xx or transport error is retried more than once or not at all, or a failure is recorded as delivered.
Grade only against these criteria; do not fail for issues they do not mention.
