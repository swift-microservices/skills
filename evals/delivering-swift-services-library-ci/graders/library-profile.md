---
type: llm
---

PASS if the generated package CI resolves without a tracked Package.resolved or a locked-build
flag, covers the package's supported stable compilers and visible snapshot checks, and includes
applicable soundness and optimized release builds. Static SDK checks must match Swift Temporal SDK:
x86_64 with the released and Swift main SDKs, on PRs only. Include the Foundation-linking gate
on Swift 6.3 Noble and Swift 6.4 Noble. It must use Linux jobs only, disable automatic API-breakage
checking, enable compact license checks, run tests/release builds on PRs/main pushes, and omit
scheduled CI. Follow the mostly `@main`
workflow profile and label Dependabot workflow-update PRs `semver/none`. Record exceptions in
AGENTS.md and avoid service deployment
branches, image publishing, or deployment credentials. The agent must distinguish checks it
actually ran from checks requiring GitHub or unavailable toolchains.

FAIL if it applies service deployment gates to this library, claims Apple-platform compatibility
from Linux success, claims runtime test coverage from SDK builds alone, claims moving
workflow references are immutable, or silently disables
all meaningful tests. Equivalent reusable workflows or focused custom jobs are acceptable.
