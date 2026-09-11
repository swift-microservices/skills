---
type: llm
---

PASS if the reply is a review report that reports no blocking or major defect in the package, target, Core, policy, or scope structure, and lists the checks that passed with one line of evidence each (for example that the policy predicate is the tenant predicate on app.caller_user_id alone, that the use case takes subject: UserIdentity and runs through withTransaction, that the Core target links only Persistence, the organization's authentication product, and Logging). A minor or a decision-for-the-user item about things the fixture omits (a missing CreateServiceRole migration file, an abridged Serve, missing tests) is acceptable and does not fail the case.
FAIL if the reply invents a blocking or major defect that the fixture does not contain, if it reports the tenant policy as a defect, if it edits a file, or if it does not list what passed.
