---
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
tags: [reviewing, mtls, configuration]
---

/swift-microservices:reviewing-swift-services .

Review the supplied Swift billing transport and configuration excerpts, read-only. Billing has a private gRPC listener, calls accounts, and starts workflows on a self-hosted Temporal cluster. It uses client certificates on both networks and is provisioned with distinct service and Temporal pairs. Identify concrete issues and what is already correct, with file-and-line evidence.

The manifest lists the target shape only; dependency declarations, implementations of makeServer/makeAccountsClient/makeTemporalClient, business logic, and tests are intentionally omitted. Assume those helpers pass their supplied transportSecurity unchanged to their transports. The pinned APIs support the reader and reloader calls shown. Do not report intentional omissions as defects or treat this as a compilable package. No edits, builds, dependency resolution, or runtime verification are requested.
