---
type: llm
---

PASS if the reply is a review report with no blocking or major finding, and a Passed section listing checks with one line of evidence each (for example the tenant predicate on `app.caller_user_id`, the use case taking `subject: UserIdentity` and running through `withTransaction`, Core linking only Persistence, the organization's authentication product, and Logging). Minor findings and decisions for the user do not fail the case.

FAIL if the reply reports a blocking or major defect, edits a file, or lists nothing that passed.
