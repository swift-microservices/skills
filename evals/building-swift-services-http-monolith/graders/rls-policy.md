---
type: llm
focus: { source: file, path: acme-backend/Sources/NotebooksPostgres/Migrations/Notebook/CreateNotebooksRLSPolicy.swift }
---

PASS if the migration enables row-level security on the notebooks table and creates a tenant policy whose predicate compares user_id to current_setting('app.caller_user_id', true) (a NULLIF guard is accepted) in both USING and WITH CHECK, without naming a role, plus an internal-role policy TO the internal role for administrator reads; revert drops what apply created.
FAIL if the tenant policy lacks WITH CHECK, names a role, admits rows beyond the caller's own, or if the predicate reads a different setting.
