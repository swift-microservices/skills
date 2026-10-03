---
max_turns: 40
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [delivery, library-ci, formatting]
---

Use the delivering-swift-services skill to configure GitHub Actions CI for a new reusable
swift-microservices library in this directory. It exports a dependency-free Swift 6.3
`LibraryCore` product and has a small existing Swift Testing suite. You may create the minimal
manifest and source files needed to demonstrate the configuration.

Use the exact Swift Temporal SDK formatting profile provided by the skill. CI should run on
Linux only; I do not want macOS CI. Check supported stable compilers, compiler snapshots,
release builds, documentation, compact license headers, formatting, and static Linux compatibility.
Disable automatic API-breakage checking. Run tests, release builds, and static SDK checks on
PRs and main pushes only, with no scheduled CI. Follow the mostly `@main` workflow references and
give Dependabot workflow-update PRs the `semver/none` label. Document exceptions in AGENTS.md.
Keep dependency resolutions untracked and use released requirements for source dependencies.
Do not add deployment branches, containers, registry publishing, or deploy credentials. Do not
commit or push. Verify what the environment permits and report remaining validation honestly.
