---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report has a Passed section listing checks that held, each with one line of evidence, for example the tenant predicate on `app.caller_user_id` in both `USING` and `WITH CHECK`, the use case taking `subject: UserIdentity` and running through `withTransaction`, or Core linking only Persistence, the organization's authentication product, and Logging; and it says the package was not built because the Acme dependency is fictional.
FAIL if nothing is listed as passed, or it claims a build or test passed.
