---
type: llm
---

PASS if the reply names the deploy secrets (a platform URL, an API token, and an application id), gives the application's command as the binary's path in the image followed by `serve --migrate-database` (for example `/app/catalog serve --migrate-database`), and states that the service carries no SemVer tags or releases because the commit is the version.
FAIL if it gives only `serve --migrate-database` without the binary's path, or proposes SemVer tags or GitHub releases for the service.
