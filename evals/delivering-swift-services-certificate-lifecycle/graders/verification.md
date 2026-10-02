---
type: llm
focus: { source: file, path: deployment.md }
---

PASS if the plan specifies how to check trusted admission, missing/untrusted/expired credentials, wrong server hostname, leaf replacement on a fresh connection, failed-reload retention and recovery, and CA trust rotation. Verification includes observed peer certificate serial/fingerprint or equivalent evidence that the new leaf was presented; it distinguishes the application's live handshake from merely inspecting renewed files. It labels these checks as planned and includes monitoring for renewal failure/remaining lifetime.
FAIL if it claims any checks or deployment were performed, uses file timestamps alone as proof of live reload, or omits a practical renewal-failure signal. Exact certificate lifetimes and reload intervals are design choices, not grading constants.
