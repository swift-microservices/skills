---
max_turns: 25
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [delivering]
---

We have a new Swift gRPC service "catalog" in the repo acme-catalog (executable product `catalog`, org "acme", images go to ghcr.io/acme). It has no CI yet. Set up the GitHub Actions workflows and the container build so every push gets an image and staging gets deployed automatically, and tell me what secrets I need to add on the repo. Write the files under ./acme-catalog and summarize.
