---
type: llm
focus: { source: file, path: Sources/CatalogWebhooks/WebhookNotifier.swift }
---

PASS if every initializer and function in the file that takes a `Logger` takes it as its last parameter (only a trailing operation closure may follow), and the notifier logs through a swift-log `Logger` it is given rather than creating its own logging setup.
FAIL if a `Logger` parameter precedes another non-closure parameter, the file calls `LoggingSystem.bootstrap` or constructs a log handler, or it prints with `print` instead of logging.
Grade only against these criteria; do not fail for issues they do not mention.
