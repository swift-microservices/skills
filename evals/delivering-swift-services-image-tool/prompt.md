---
max_turns: 25
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [delivering]
---

We have a Swift gRPC service "catalog" in the repo acme-catalog (executable product `catalog`, org "acme", images go to ghcr.io/acme). Its AGENTS.md records our image decision: images are built with swift-container-plugin and the static Linux SDK (aarch64 musl) on ARM64 runners, with no Containerfile and no Docker daemon. It has no CI yet. Set up the GitHub Actions workflows that build, publish, and deploy that image to staging on every push to develop, and tell me what secrets I need. Write the files under ./acme-catalog and summarize.
