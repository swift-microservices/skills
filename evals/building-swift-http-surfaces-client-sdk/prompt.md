---
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [http, sdk]
---

Our organization "acme" runs a Hummingbird API gateway whose OpenAPI contract is at ./acme-api/Sources/API/openapi.yaml. Create the Swift client SDK our iOS and macOS apps will use: a new package under ./acme-sdk with one library target, AcmeSDK, generated from that contract. Sign-in and token refresh should go through swift-openapi-token-authentication (https://github.com/swift-microservices/swift-openapi-token-authentication, version 0.2.2); put its authentication client conformance in Sources/AcmeSDK/AcmeAuthenticationClient.swift and the problem details type in Sources/AcmeSDK/Problem.swift. Apps should get a URLSession transport without configuring anything, while our Linux command-line tools bring their own ClientTransport and must be able to build the SDK without URLSession. Leave ./acme-api unchanged, do not build or resolve packages, and finish with a short summary.
