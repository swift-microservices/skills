---
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [delivering, library-ci, generated]
---

Apply our standard library CI to this generated SDK. It has no runtime tests and a default URLSession transport trait. Validate the generated public API from a separate consumer package at .github/Fixtures/Consumer, and the custom-transport configuration too. Our last release-consumer linkage check listed libFoundation.so both with default traits and with `--disable-default-traits`, because the generated code imports Foundation. Preserve its MIT license and owner. Document supported configurations and justified upstream exceptions in AGENTS.md.

Put pull-request CI in .github/workflows/pull_request.yml, main-branch CI in .github/workflows/main.yml, the build matrix in a reusable .github/workflows/builds.yml, the SemVer label check in .github/workflows/pull_request_label.yml, and Dependabot in .github/dependabot.yml. Do not commit, push, publish, or change repository settings. Validate what is available locally and distinguish local results from checks requiring GitHub, Linux, or provider access.
