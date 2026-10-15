# Error translation

How a use case's typed error becomes an RFC 9457 problem response: the shared protocol, each error's mapping, and the error middleware. The rest of the surface is in [surface.md](surface.md).

## Contents



## Error translation

Answer every failure as RFC 9457 problem details with `application/problem+json`. The problem plumbing lives in `<Project>HTTP` in a monolith and in the surface target otherwise (`Middlewares/ErrorMiddleware/` with `Problem/` and `Problem/Conformances/`):

```swift
// Problem.swift
import HTTPTypes
import Hummingbird

/// RFC 9457 problem details.
package struct Problem: Encodable, Sendable {
    package let type: String
    package let title: String
    package let status: Int
    package let detail: String?
    package let instance: String?

    func response(status: HTTPResponse.Status, from request: Request, context: some RequestContext) throws -> Response {
        var response = try context.responseEncoder.encode(self, from: request, context: context)
        response.status = status
        response.headers[.contentType] = "application/problem+json"
        return response
    }
}
```

```swift
// HTTPProblemResponse.swift
package import Hummingbird

package protocol HTTPProblemResponse: HTTPResponseError {
    var type: String { get }
    var title: String { get }
    var detail: String? { get }
}

extension HTTPProblemResponse {
    package var type: String { "about:blank" }

    /// Public, unlike the rest of this protocol: it is the witness for Hummingbird's public
    /// `ResponseGenerator` requirement on public types this target does not own, such as `RPCError`.
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let problem = Problem(type: type, title: title, status: status.code, detail: detail, instance: request.uri.path)
        return try problem.response(status: status, from: request, context: context)
    }
}
```

```swift
// ErrorMiddleware.swift
import HTTPTypes
package import Hummingbird
import Logging

package struct ErrorMiddleware<Context: RequestContext>: RouterMiddleware {
    package init() {}

    // `next` is spelled `@concurrent` to match `RouterMiddleware`: Hummingbird is built without
    // NonisolatedNonsendingByDefault, which would otherwise make this closure nonisolated(nonsending).
    package func handle(
        _ input: Request,
        context: Context,
        next: @concurrent (Request, Context) async throws -> Response
    ) async throws -> Response {
        do {
            return try await next(input, context)
        } catch let error as any HTTPProblemResponse {
            if error.status.kind == .serverError {
                context.logger.error("Request failed", metadata: ["error": "\(String(reflecting: error))"])
            }
            return try error.response(from: input, context: context)
        } catch let error as HTTPError {
            let problem = Problem(type: "about:blank", title: error.status.reasonPhrase, status: error.status.code, detail: error.body, instance: input.uri.path)
            return try problem.response(status: error.status, from: input, context: context)
        } catch {
            context.logger.error("Unhandled error", metadata: ["error": "\(String(reflecting: error))"])
            let problem = Problem(type: "about:blank", title: "Internal Server Error", status: 500, detail: nil, instance: input.uri.path)
            return try problem.response(status: .internalServerError, from: input, context: context)
        }
    }
}
```

In a module's surface, conform each use case's typed error in `<Module>HTTP`, so a handler just `try await`s the use case and the middleware answers. The statuses mirror the gRPC producer adapter's: invalid input `400`, an idempotency key reused with different input `400`, an absent caller `401` (from the context), `.forbidden` `403`, not found `404`, a duplicate `409`, `.unknown` `500`, which the middleware logs. A handler sees one use-case error enum, never `PSQLError` or a repository error, which persistence and Core already classified:

```swift
// CatalogHTTP/Problem/CreateItemUseCaseError+HTTPProblemResponse.swift
import CatalogCore
import HTTPTypes
import Hummingbird
import <Project>HTTP

extension CreateItemUseCaseError: HTTPProblemResponse {
    package var status: HTTPResponse.Status {
        switch self {
        case .invalidName: .badRequest
        case .forbidden: .forbidden
        case .duplicateName: .conflict
        case .unknown: .internalServerError
        }
    }

    package var title: String {
        switch self {
        case .invalidName: "Invalid Name"
        case .forbidden: "Forbidden"
        case .duplicateName: "Duplicate Name"
        case .unknown: "Internal Server Error"
        }
    }

    package var detail: String? { nil }
}
```

In a gateway, conform `RPCError` and map it by code rather than collapsing it:

| gRPC code | HTTP |
| --- | --- |
| `invalidArgument`, `failedPrecondition`, `outOfRange` | 400 |
| `unauthenticated` | 401 |
| `permissionDenied` | 403 |
| `notFound` | 404 |
| `alreadyExists`, `aborted` | 409 |
| `resourceExhausted` | 429 |
| `cancelled` | 499 |
| `unimplemented` | 501 |
| `unavailable` | 503 |
| `deadlineExceeded` | 504 |
| anything else | 500 |

```swift
// RPCError+HTTPProblemResponse.swift
public import GRPCCore
public import HTTPTypes
public import Hummingbird

// Retroactive by necessity: the gateway owns neither RPCError nor HTTPResponseError.
// swift-format-ignore: AvoidRetroactiveConformances
extension RPCError: @retroactive HTTPResponseError, HTTPProblemResponse {
    package var title: String { message }
    package var detail: String? { nil }

    // Public for the same reason as `response(from:context:)`: a public type's witness for a public requirement.
    public var status: HTTPResponse.Status {
        switch code {
        case .invalidArgument, .failedPrecondition, .outOfRange: .badRequest
        case .unauthenticated: .unauthorized
        case .permissionDenied: .forbidden
        case .notFound: .notFound
        case .alreadyExists, .aborted: .conflict
        case .resourceExhausted: .tooManyRequests
        case .cancelled: 499
        case .unimplemented: .notImplemented
        case .unavailable: .serviceUnavailable
        case .deadlineExceeded: .gatewayTimeout
        default: .internalServerError
        }
    }
}
```

The producing service already classified the failure into a status its contract defines; mapping every RPC failure to `500` discards that at the last hop and tells a client to retry what cannot succeed. `500` is reserved for what the surface cannot classify, and the middleware logs it with the underlying error.
