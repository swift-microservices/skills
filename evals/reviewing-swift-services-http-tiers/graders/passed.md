---
type: llm
---

PASS if the report lists checks that passed with one line of evidence each, including that `AdminRequestContext` carries `coreContext` across and distinguishes 401 from 403, and that `UserSettingsMiddleware` follows the bearer middleware in the identifying tier; it reports omitted parts as limitations or not applicable rather than as defects, and orders findings by severity.
FAIL if it reports `AdminRequestContext` or the middleware order as a defect, invents defects in omitted parts, or lists nothing that passed.
