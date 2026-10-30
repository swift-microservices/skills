---
runs: 1
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [delivering, library-ci, postgres]
---

Set up this library's CI the way we standardize our libraries. Put the workflows in .github/workflows/pull_request.yml and main.yml, the database tests in .github/workflows/tests.yml, Dependabot in .github/dependabot.yml, and record the CI profile in AGENTS.md. Do not commit, push, or change repository settings. Report what you validated and what only GitHub can run.
