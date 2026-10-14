---
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [delivering, service-ci]
---

Align this deployable application's CI with our recommended service profile. Preserve the existing behavior tests and the deployment and style choices in AGENTS.md. Validate the actual release image before it is published. Do not add database, vendor, or full-stack test fixtures. Keep library and application dependency policies distinct.

Put the reusable checks in .github/workflows/checks.yml, the reusable image build in .github/workflows/image.yml with its validation script at .github/scripts/check-image.sh, and the branch workflows in .github/workflows/pull_request.yml, develop.yml, and main.yml. Do not commit, push, publish, deploy, or change repository settings. Report available validation honestly, including checks requiring Linux, a container runtime, or GitHub access.
