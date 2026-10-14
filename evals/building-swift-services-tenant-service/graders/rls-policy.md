---
type: llm
focus: { source: file, path: acme-documents/Sources/DocumentsPostgres/Migrations/Document/CreateDocumentsRLSPolicy.swift }
---

PASS if the migration enables row-level security on the documents table and creates a tenant policy whose predicate compares user_id to current_setting('app.caller_user_id', true) (a NULLIF guard is accepted) in both USING and WITH CHECK, without naming a role, plus a policy TO the internal role; revert drops what apply created.
FAIL if the tenant policy (the one reading `app.caller_user_id`) lacks WITH CHECK, has a `TO` clause in its SQL, admits rows beyond the caller's own, or reads a different setting. The separate internal-role `USING (true)` policy is required, and comments that describe roles do not count as naming one.
