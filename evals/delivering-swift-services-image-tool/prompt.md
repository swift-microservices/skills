---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [delivering, image-tool]
---

We have a Swift gRPC service "catalog" in the repo acme-catalog (executable product `catalog`, org "acme", images go to ghcr.io/acme). Its AGENTS.md records our image decision: images are built with swift-container-plugin and the static Linux SDK (aarch64 musl) on ARM64 runners, with no Containerfile and no Docker daemon. It has no CI yet. Set up the GitHub Actions workflows that build, publish, and deploy that image to staging on every push to develop: the shared checks in .github/workflows/checks.yml, the image build in .github/workflows/image.yml, both called from .github/workflows/pull_request.yml and develop.yml. Tell me what secrets I need and anything I have to record or change in AGENTS.md. Write the files under ./acme-catalog and summarize.
