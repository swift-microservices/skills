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

Do not run a guaranteed-failing swift test or create placeholder tests. Replace it with a matching
four-toolchain library+actual consumer build and preserve release/static/DocC. Check default and
--disable-default-traits for both the SDK and consumer, correctly forwarding traits in the consumer
manifest. The consumer must use generated symbols, not only an empty import. Generated Foundation
imports affect both configurations, so a recorded full-Foundation exception may omit the gate;
do not fabricate Foundation-free support. Generated output stays untracked.
A demonstrated generated-import warning can remain a visible warning on Swift 6.4 only via
`-Xswiftc -Wwarning -Xswiftc UnusedImportAccess`, documented with a removal condition. Other
stable warnings still fail. Do not use this unknown group on Swift 6.3.
Run checker with `--no-tests --traits --foundation-exception generator`, adding
`--warning-exception UnusedImportAccess` only when that documented exception is used.
