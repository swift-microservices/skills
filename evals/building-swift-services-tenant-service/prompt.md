---
max_turns: 30
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building]
---

I'm starting a new Swift gRPC service called "documents" for our organization "acme". Each user owns their documents, and administrators can list every document. Scaffold the SwiftPM package: the targets, the manifest, a Document entity with a create and a list use case, the Postgres side including migrations and the policy that keeps users apart, and the serve command. Write the files into ./acme-documents and finish with a short summary of what you created.
