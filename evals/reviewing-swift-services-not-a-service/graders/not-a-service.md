---
type: llm
focus: trace
---

Judge the review (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the reviewer says this package is a reusable library, not a service, monolith, or gateway, and points the audit to the building-swift-server-libraries skill's completion gates (or audits it against those library gates) instead of the service checklist.
FAIL if it audits the package as a service.
