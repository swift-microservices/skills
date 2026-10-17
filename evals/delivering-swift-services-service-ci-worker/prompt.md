---
runs: 1
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [delivering, service-ci, worker]
---

Align this deployable application's CI with our recommended service profile. Preserve the existing behavior tests and the deployment and style choices in AGENTS.md. Do not add database, vendor, or full-stack test fixtures. Keep library and application dependency policies distinct.

Put the workflows in .github/workflows/pull_request.yml, main.yml, deploy.yml for production, and cleanup-images.yml, and Dependabot in .github/dependabot.yml. Do not commit, push, publish, deploy, or change repository settings. Report available validation honestly, including checks requiring Linux, a container runtime, or GitHub access.
