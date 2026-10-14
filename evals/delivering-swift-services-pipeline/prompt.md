---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [delivering, pipeline]
---

We have a new Swift gRPC service "catalog" in the repo acme-catalog (executable product `catalog`, org "acme", images go to ghcr.io/acme). It owns a Postgres database whose migrations ship with the service. It has no CI yet. Set up the GitHub Actions workflows and the container build so every push gets an image and staging gets deployed automatically. Lay the workflows out as .github/workflows/pull_request.yml, develop.yml, and main.yml, with the shared checks in a reusable .github/workflows/checks.yml and the image build and publish in a reusable .github/workflows/image.yml. Old images shouldn't pile up in ghcr.io forever; put whatever handles that in .github/workflows/cleanup-images.yml.

Write the files under ./acme-catalog and summarize. In the summary, tell me what secrets I need to add on the repo, what command the deployed application runs, whether we should start tagging versioned releases of catalog, how I roll staging back to an earlier commit if a deploy goes wrong, and what I have to watch for in schema changes now that staging deploys on every push.
