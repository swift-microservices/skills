---
type: llm
focus: { source: file, path: Sources/Acme/Serve/Serve.swift }
---

PASS if all of these hold:
- The router adds the shared `ErrorMiddleware` before the route groups, and route prefixes such as `v1` and `items` are set here rather than inside the controllers' route paths.
- The Hummingbird `Application` reads its listener from `ApplicationConfiguration(reader: config.scoped(to: "http.server"))`.
- The application runs in the existing `ServiceGroup` beside the gRPC server, built over the same use-case values the gRPC service uses.

FAIL if the HTTP application runs outside the `ServiceGroup`, the listener host or port is hard-coded, or a second set of use cases is constructed for HTTP.
Grade only against these criteria; do not fail for issues they do not mention.
