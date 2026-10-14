---
type: llm
focus: { source: file, path: stack/compose.yaml }
---

PASS if every value the stack cannot start without (database owner and role passwords, image tags, and the paths of key, root-certificate, and token files) is a required variable written `${VAR:?message}`, so `docker compose up` refuses to start with an actionable error when it is missing.
FAIL if a password or secret has a usable default (`${VAR:-something}` or a literal), a required value uses a bare `${VAR}` that silently becomes empty, or a secret value is written literally in the file.
