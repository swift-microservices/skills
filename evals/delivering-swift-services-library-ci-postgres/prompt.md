---
max_turns: 50
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [delivery, library-ci]
---

Use delivering-swift-services to add the standard library CI to DatabaseCore. Its existing
provider test must run against a real PostgreSQL 18 server. Keep its MIT license and owner.
Document any genuine dependency exception; this is a library, not a deployment.

Put the workflows where the skill's layout puts them. Do not commit, push, publish, or change repository settings. Validate what is available locally
and distinguish local results from checks requiring GitHub/Linux/provider access.
