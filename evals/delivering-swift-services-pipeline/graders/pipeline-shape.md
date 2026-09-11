---
type: llm
---

PASS if the result has separate workflows for pull requests (tests only), pushes to develop (tests, then publish, then a deploy to staging), and pushes to main (tests, then publish, then production deploy); the publish step pushes two tags, an immutable short commit SHA and the moving branch name; the tests run `swift test --disable-automatic-resolution` against the committed Package.resolved; a static Linux SDK build is present; the deploy step is a single trigger bound to plain secrets that fails the run when a secret is missing rather than skipping; the summary names the deploy secrets (a platform URL, an API token, an application id) and says the application's command is `./catalog serve --migrate-database`.
FAIL if the service is given SemVer tags or GitHub releases, if the deploy step is conditional on a secret being present, if images are tagged only `latest`, if a separate migration job is added, or if the workflows build under emulation for a different architecture than the deploy host.
