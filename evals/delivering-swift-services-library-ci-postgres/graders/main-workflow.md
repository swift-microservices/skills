---
type: llm
focus: { source: file, path: .github/workflows/main.yml }
---

PASS if this workflow runs on `push` to `main` and has the same test job as the pull-request workflow (a job calling the repository's reusable `./.github/workflows/tests.yml` database matrix in place of `unit_tests.yml`), an `apple/swift-nio/.github/workflows/release_builds.yml@main` job with `minimum_swift_version: "6.3"` and `linux_6_2_enabled: false`, and no Foundation linking job, because the sole product links PostgresNIO, which requires full Foundation upstream (the exception recorded in AGENTS.md).
FAIL if it runs the static SDK workflow, a soundness job, a schedule, or a macOS job.
