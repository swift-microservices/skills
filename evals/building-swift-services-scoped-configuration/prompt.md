---
max_turns: 50
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, configuration, mtls]
---

Write the configuration layer for two Swift executables, ./acme-catalog and ./acme-mailer. Catalog serves gRPC and also starts Temporal workflows; Mailer only runs a Temporal worker. We want short composition roots and consistent configuration APIs that each executable can use with its own mounted files.

Catalog's service credentials are under /run/catalog-peer/{cert.pem,key.pem,ca.pem}; its distinct Temporal credentials are under /run/catalog-temporal/{cert.pem,key.pem,ca.pem}. Mailer's Temporal credentials are under /run/mailer-temporal/{cert.pem,key.pem,ca.pem}. Operators must be able to override each path independently with environment variables. Mailer must start with only its Temporal and worker-database settings; serving and migration secrets are absent.

The pinned libraries offer native Swift Configuration support for Hummingbird ApplicationConfiguration(reader:), Temporal client/worker Configuration(configReader:), and ValkeyClientConfiguration(configReader:). Catalog also uses Valkey; its native reader covers tuning, but not endpoint or TLS construction. TimedCertificateReloader.Configuration and the gRPC transport security types do not offer native readers. Use these as API facts for this offline exercise; no network access or dependency resolution is available.

Write executable-local application defaults, the reusable reloader and transport-security extensions, small Serve/Run excerpts showing their use and lifecycle, and .env.example files documenting paths and duration settings. Include service connection age/grace settings and a certificate refresh interval. Do not add arbitrary validation guards. In ./configuration-notes.md explain what the executable owns versus what a library adopting ConfigReader should own, and how native support changes which adapters are needed. No complete service scaffold is needed.
