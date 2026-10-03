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

This package has no full-Foundation dependency: both Foundation consumer checks are required.
FAIL for service's 400-column formatter, substituted workflow families/default matrices, hidden
snapshot failures, extra static architectures/SDK versions, or loss of existing behavior tests.
