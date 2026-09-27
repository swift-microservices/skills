---
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill, Bash]
tags: [reviewing, swift-settings, concurrency]
---

Use the reviewing-swift-services skill for a read-only review of this small Swift server utility package's language settings, imports, and isolation safety. Keep the intentional library-plus-executable shape out of scope. Report concrete findings with file and line evidence, and say what passed. Does setting Swift tools 6.3 and Swift 6 mode ensure all targets get the new behavior? Can the library settings configure the application and tests? Do not modify files, install dependencies, commit, or push. Build if possible and distinguish environment failures from source failures.
