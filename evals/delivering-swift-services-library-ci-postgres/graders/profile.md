---
type: llm
---

PASS only if artifacts follow the delivering-swift-services standard library profile, not
service/deployment defaults: Linux 6.3/6.4 + next/main matrices with correct flags, optimized
release builds on PRs/main, unmodified default x86_64 released/main static SDK workflow on PRs
only, soundness with API checks disabled and compact headers enabled, strict exact formatter,
DocC targets, no schedule/macOS/API-diff job, released source dependencies, untracked/ignored
resolved files, SemVer PR label check and weekly Actions Dependabot with semver/none. Shared
workflow refs follow the profile. Tests must not be deleted merely to fit generic workflows.
Report validation honestly. Check actual YAML/Swift artifacts and effective coverage; wording
in AGENTS.md alone is not sufficient. Run the independent checker from the original plugin:
`python3 evals/delivering-swift-services-library-ci/checks/verify.py <workspace>` (requires PyYAML).

The database matrix must attach a healthy postgres:18-alpine service on all four toolchains,
use TCP pg_isready, matching credentials/database/hostname, and run actual swift test --parallel.
FAIL for inherited generic tests without database provisioning, Unix-only readiness, missing
snapshot/stable flags, database-unavailable skips, mocks replacing the real query, or claiming
PostgresNIO is Foundation-free. The sole database product may explicitly omit linking checks
for the upstream PostgresNIO exception, retaining release/static coverage.
Run checker with `--provider postgres --foundation-exception PostgresNIO`.
