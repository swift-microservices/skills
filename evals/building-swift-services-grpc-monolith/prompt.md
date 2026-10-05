---
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, monolith, grpc]
---

Our organization "acme" runs a Swift backend for a mobile app that talks gRPC directly. It's one process with one Postgres database, but keep it modular: a users module (sign-up, sign-in, profile) and a catalog module (items every signed-in user can read, administrators can create). Both modules expose gRPC services from the same server. Scaffold the SwiftPM package under ./acme-backend: the targets and manifest, both modules' Core and Postgres sides with migrations, the gRPC adapters, and the serve command with its interceptors. Assume the proto contracts already exist in acme-protos as Acme_Users_V1_UserService and Acme_Catalog_V1_ItemService, each holding its module's public, signed-in, and administrator RPCs. Name the executable target Acme with its composition root in Sources/Acme/Serve/Serve.swift and its ordered migrations list in Sources/Acme/Database/Migrations.swift, put the item-creation use case in Sources/CatalogCore/Items/UseCases/CreateItem/CreateItemUseCase.swift, and put the users gRPC conformance in Sources/UsersGRPC/Users/UserService.swift. Finish with a short summary.
