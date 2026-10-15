---
runs: 1
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [delivering, compose, mtls]
---

We're bringing our Swift stack up on a fresh host for the first time, starting from an empty directory. It runs published images from ghcr.io/acme: `acme-api` (the public HTTP gateway, which should be reachable only through a Tailscale sidecar), `acme-accounts` (gRPC; it issues the access tokens, so it signs them; its own Postgres), and `acme-orders` (gRPC with its own Postgres, plus a Temporal worker from the same image run as `orders worker run`; Temporal itself is external and also requires client certificates, which we issue from the same CA as a separate pair per process, because one Temporal server serves both our environments; the worker's longest Activity can take up to two minutes). Every internal call uses mTLS from a private Smallstep CA that doesn't exist yet.

Write ./stack/compose.yaml with every service in that one file (the CA, certificate enrollment, and renewal included), ./stack/.env.example, any scripts the first start needs under ./stack, and ./stack/FIRST-START.md with the order of operations from nothing to a running stack and how to verify it once it's up. Don't run docker or contact anything; this is the design we'll apply.
