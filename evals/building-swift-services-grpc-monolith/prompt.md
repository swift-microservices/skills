---
max_turns: 80
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, monolith, grpc]
---

Our organization "acme" runs a Swift backend for a mobile app that talks gRPC directly. It's one process with one Postgres database, but keep it modular: a users module (sign-up, sign-in, profile) and a catalog module (items every signed-in user can read, administrators can create). Both modules expose gRPC services from the same server. Scaffold the SwiftPM package under ./acme-backend: the targets and manifest, both modules' Core and Postgres sides with migrations, the gRPC adapters, and the serve command with its interceptors. Assume the proto contracts already exist in acme-protos as Acme_Users_V1_UserPublicService, Acme_Users_V1_UserService, Acme_Catalog_V1_ItemPublicService, and Acme_Catalog_V1_ItemService. Finish with a short summary.
