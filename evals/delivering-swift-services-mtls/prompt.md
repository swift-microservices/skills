---
max_turns: 20
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [delivering]
---

I'm adding a new service "notifications" to our compose stack (org "acme", project "acme"). All our gRPC traffic is mutual TLS with certificates the stack issues itself. What do I add to compose.yml and the certificate script so notifications and its worker get their certificates, and how does the service find them? Show the compose service definitions and the certificate changes.
