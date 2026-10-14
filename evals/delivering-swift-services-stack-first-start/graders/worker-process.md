---
type: llm
focus: { source: file, path: stack/compose.yaml }
---

PASS if the orders worker runs the same `acme-orders` image and tag as orders with the command `worker run`, receives only the worker database role's credentials (no owner and no serving-role password), and has a stop grace period longer than its two-minute Activity drain.
FAIL if the worker gets the owner or a serving role's password, uses another image or tag, or keeps the default ten-second grace.
