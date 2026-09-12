---
max_turns: 80
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, monolith, http]
---

We're a small team at "acme" starting a backend for a note-taking product. It's one deployable Swift server over plain HTTP on Hummingbird, no gRPC: users sign up and sign in, and each user owns their notebooks; administrators can list every notebook. Keep it modular so we could split it later, but ship one process with one Postgres database. Scaffold the SwiftPM package under ./acme-backend: the targets and manifest, the notebooks module with a create and a list use case, the Postgres side including migrations and the policy that keeps users apart, the HTTP routes, and the serve command. Finish with a short summary.
