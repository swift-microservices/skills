---
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [delivering, mtls, dokploy]
---

We deploy our Swift gateway, accounts and billing services, and a billing Temporal worker in one Dokploy project, with staging and production environments. Temporal is self-hosted. Internal connections require mTLS. Applications support runtime leaf-certificate reload from mounted files; billing's service calls and Temporal connection use distinct credential pairs.

Write ./deployment.md with a practical deployment design for issuing and rotating these credentials using Smallstep in this Dokploy project. Cover the CA and renewers, first startup, per-application mounts, environment configuration, and application reload lifecycle. Put how to verify a rotation, and how to monitor renewal, in ./verification.md. Include representative enrollment/renewal/rekey commands or deployment fragments with placeholders for secrets. Treat this as a design artifact: do not call Dokploy, issue real credentials, or claim to deploy anything. Keep it focused on certificates and the service network; application CI and database migrations already exist.
