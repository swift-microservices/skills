---
runs: 1
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [libraries, operation-context]
---

We're adding a small open-source package, swift-request-id (https://github.com/swift-microservices/swift-request-id), beside our swift-operation-context package (https://github.com/swift-microservices/swift-operation-context; the `OperationContext` API we need has been there since 0.1.0). Server code wants the current request's id anywhere inside the work for that request (log metadata, outgoing calls) without threading it through every signature. The package carries a `RequestID` value through `OperationContext`: it offers a scoped call that runs an operation with an id bound, and anything inside that operation reads the current id through a typed property. Transport bindings in other packages will call the scoped API later; nothing else should be able to change the id in place.

Create the package under ./swift-request-id: the manifest, the `RequestID` type in Sources/RequestID/RequestID.swift, the key, the typed property, and the scoped binding in Sources/RequestID/OperationContext+RequestID.swift, and the tests in Tests/RequestIDTests/RequestIDTests.swift. It is MIT-licensed; the copyright owner is Example Authors.

Networking and dependency resolution are unavailable, so don't build or resolve. Finish with a short summary of the public API.
