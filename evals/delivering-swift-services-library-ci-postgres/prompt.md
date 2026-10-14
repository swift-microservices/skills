---
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [delivering, library-ci, postgres]
---

Add our standard library CI to DatabaseCore. Its existing provider test must run against a real PostgreSQL 18 server. Keep its MIT license and owner. Document any genuine dependency exception in AGENTS.md; this is a library, not a deployment.

Put pull-request CI in .github/workflows/pull_request.yml, main-branch CI in .github/workflows/main.yml, the database test matrix in a reusable .github/workflows/tests.yml, the SemVer label check in .github/workflows/pull_request_label.yml, and Dependabot in .github/dependabot.yml. Do not commit, push, publish, or change repository settings. Validate what is available locally and distinguish local results from checks requiring GitHub, Linux, or provider access.
