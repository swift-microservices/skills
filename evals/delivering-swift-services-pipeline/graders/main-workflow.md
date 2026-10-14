---
type: llm
focus: { source: file, path: acme-catalog/.github/workflows/main.yml }
---

PASS if this workflow runs on `push` to `main`, runs the same checks, and publishes the image after them; a production deploy after publication, or a marked placeholder for it while only staging exists, is acceptable.
FAIL if it publishes before the checks, publishes the `develop` tag from main, or creates SemVer tags or GitHub releases.
