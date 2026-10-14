---
max_turns: 150
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [http, monolith]
---

Our modular monolith acme-backend (this directory) only serves gRPC today. Give the catalog module an HTTP API on Hummingbird for our web client, over the use cases already in CatalogCore: anyone can list the catalogue and read an item, administrators add items, and signed-in users list and add their own favourites (favorites rows are under row-level security on `app.caller_user_id`). The other modules will get HTTP surfaces later, so put what they will share in a new AcmeHTTP target.

Put the module's HTTP code in a new CatalogHTTP target: its OpenAPI document and generator configuration in Sources/CatalogHTTP/, the controllers in Sources/CatalogHTTP/Controllers/ItemController.swift and FavoriteController.swift, and each use-case error's HTTP mapping in Sources/CatalogHTTP/Problems/<ErrorType>+Problem.swift. Put the shared request contexts in Sources/AcmeHTTP/Contexts/ (one file per type) and the shared error middleware in Sources/AcmeHTTP/Middlewares/ErrorMiddleware/ErrorMiddleware.swift. Wire the routes and the HTTP server into Sources/Acme/Serve/Serve.swift, update Package.swift, and add tests in Tests/CatalogHTTPTests/CatalogHTTPTests.swift.

The tree is an abridged excerpt and networking is unavailable, so don't build or resolve packages. Finish with a short summary.
