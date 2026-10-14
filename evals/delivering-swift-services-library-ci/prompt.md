---
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [delivering, library-ci]
---

Set up our standard CI for this reusable server library. The existing RetryBudget tests are intentional behavior coverage. Keep its MIT license and owner. Apply our standard formatter, headers, dependency resolution, and workflow policies, and record the repository profile in AGENTS.md.

Put pull-request CI in .github/workflows/pull_request.yml, main-branch CI in .github/workflows/main.yml, the SemVer label check in .github/workflows/pull_request_label.yml, and Dependabot in .github/dependabot.yml. Do not commit, push, publish, or change repository settings. Validate what is available locally and distinguish local results from checks requiring GitHub, Linux, or provider access.
