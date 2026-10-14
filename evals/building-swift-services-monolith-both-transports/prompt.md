---
max_turns: 150
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, monolith, http, grpc]
---

Our organization "acme" runs a lending-library app. We want one deployable Swift server with one Postgres database, kept modular so a module could be split out later. There are two modules: members (sign-up, sign-in, each member's own profile; administrators can look up any member) and loans (a signed-in member borrows a book and lists their own loans; administrators list every loan). Borrowing must refuse a member whose membership is suspended, and only the members module knows that. The web app calls HTTP routes on Hummingbird and the mobile app calls gRPC; serve both from the same process. We have no shared core package and no protos repository yet. Scaffold the SwiftPM package under ./acme-library: the targets and manifest, both modules' Core and Postgres sides with migrations and the policies that keep members apart, the HTTP routes, the gRPC services, and the serve command. Name the executable target Acme with its composition root in Sources/Acme/Serve/Serve.swift and its ordered migrations list in Sources/Acme/Database/Migrations.swift, put the borrowing use case in Sources/LoansCore/Loans/UseCases/BorrowBook/BorrowBookUseCase.swift, and put the loans module's tenant-scoped database scope in Sources/LoansPostgres/Scopes/PostgresLoansScope.swift. Finish with a short summary.
