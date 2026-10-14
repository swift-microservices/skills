---
type: llm
focus: trace
---

Judge the review report: the last assistant text, which may come back from a forked review agent as a tool result or command output and be relayed in the final reply. The skill instructions earlier in the trace are not the report.

PASS if the report's passed checks give one line of evidence each, and among them say that `AdminRequestContext` carries `coreContext` across and answers 401 without an identity and 403 for a non-administrator, that `UserSettingsMiddleware` follows the bearer middleware in the identifying tier, and that the requiring tier sits inside the identifying tier under `IsAuthenticatedMiddleware` (in any words, with or without naming `identified.group()`).

A question about problem details under "Decisions for the user" is not a defect, and citing `AdminRequestContext` as the correct example in another finding's fix is not a defect either.

FAIL if a finding reports `AdminRequestContext`, the middleware order, or the requiring tier as a defect, or the report lists nothing that passed.
