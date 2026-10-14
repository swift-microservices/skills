---
type: llm
focus: { source: file, path: swift-persistence-memory/AGENTS.md }
---

PASS if AGENTS.md has a releases section stating exactly one SemVer label per pull request (`⚠️ semver/major`, `🆕 semver/minor`, `🔨 semver/patch`, or `semver/none`), the repository's release mechanism (an Auto Release workflow or hand-cut version tags), that published tags never move, and that consumers pin by tag, never by branch or path.
FAIL if the file is missing, it says to commit `Package.resolved`, or it allows moving a tag or pinning by branch.
Grade only against these criteria; do not fail for issues they do not mention.
