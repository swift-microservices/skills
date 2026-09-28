---
max_turns: 80
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, gateway]
---

Our organization "acme" has two Swift gRPC services, users and catalog, each with a public and a user-facing proto service (Acme_Users_V1_UserPublicService, Acme_Users_V1_UserService, Acme_Catalog_V1_ItemPublicService, Acme_Catalog_V1_ItemService). Put an HTTP API in front of them on Hummingbird so the web client can sign in, refresh its session, read the catalog anonymously, and manage its own profile when signed in. Scaffold the package under ./acme-api: targets, manifest, the request contexts, the router setup with its tiers, one controller per resource, the error handling, and the serve command. Name the executable target Acme with its serve command in Sources/Acme/Serve/Serve.swift; build the router and its tiers in Sources/API/AcmeAPI.swift, put the admin request context in Sources/API/Contexts/AdminRequestContext.swift, and the RPCError problem mapping in Sources/API/Middlewares/ErrorMiddleware/Problem/Conformances/RPCError+HTTPProblemResponse.swift. Finish with a short summary.

The gateway and upstreams use SPIFFE in `prod.acme.example`; users and catalog are `spiffe://prod.acme.example/users` and `spiffe://prod.acme.example/catalog`. Identity-provider material is supplied to the composition root. Include secure upstream client wiring.
