---
max_turns: 50
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
tags: [building, swift-settings, concurrency]
---

Use the building-swift-services skill to migrate this small Swift server utility package to the organization's Swift 6.3 settings. It intentionally exports a reusable library and a command-line application; keep that shape and do not add infrastructure or dependencies. Apply the settings to all relevant targets and briefly explain each setting, including tools version versus language mode and default actor isolation.

Preserve the public API names and behavior. InlineRunner is a sequential scoped operation: its closure should stay on the caller's actor and be able to mutate caller-owned non-Sendable state. The extension call in UtilityApp must still work. Fix source issues exposed by the settings and add meaningful Swift Testing coverage for a custom actor and MainActor caller in Tests/UtilityTests/UtilityTests.swift. Build and test where the environment permits; report limitations honestly. Do not commit or push.
