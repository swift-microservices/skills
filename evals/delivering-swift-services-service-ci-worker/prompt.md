---
max_turns: 50
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [delivery, service-ci]
---

Use delivering-swift-services to align this deployable application's CI with our recommended
service profile. Preserve the existing behavior tests and the deployment/style choices in
AGENTS.md. Validate the actual release image before it is published. Do not add database,
vendor or full-stack test fixtures. Keep library and application dependency policies distinct.

Put the workflows where the skill's layout puts them. Do not commit, push, publish, deploy or change repository settings. Report available validation
honestly, including checks requiring Linux/container/GitHub access.
