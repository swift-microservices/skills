# Identity and access

How a caller is identified across services, who may mint a token, how the credential travels, how a process that acts on its own behalf is identified, and where the decision about what a caller may do is made.

## Contents

- The packages
- One issuer, asymmetric keys
- The user identity
- What belongs in the token
- Signing
- Identifying a caller versus requiring one
- Where the caller lives
- Authorization lives in the use case
- One RPC service per audience
- Propagating the caller
- Processes: the certificate is the credential
- The three rules
- Reading the credential
- Key material in configuration
- Rotation

## The packages

Every service shares one shape for a proven caller, consumed by tagged URL beside `<project>-protos`. The generic half is the [swift-microservices](https://github.com/swift-microservices) authentication family, which knows nothing about the organization, its token, or its roles. Every type in it is generic over the credential that was presented and the identity it proves.

| Package | Product | Depends on | For |
| --- | --- | --- | --- |
| swift-authentication | `Authentication` | swift-service-context | `Authenticator<Credential, Identity>`, `CredentialIssuer`, `Principal<Identity, Credential>`, `PrincipalKey` — the shape, with no credential in it |
| swift-authentication-jwt | `AuthenticationJWT` | jwt-kit | `JWTIssuer<Payload>` and `JWTAuthenticator<Payload>` over a `JWTKeyCollection` |
| swift-authentication-x509 | `AuthenticationX509` | swift-certificates | `SPIFFEID`, `SPIFFEAuthenticator` — a peer by the SPIFFE name in its certificate |
| swift-authentication-grpc | `AuthenticationGRPC` | grpc-swift-2 | `BearerAuthenticationInterceptor`, `BearerPropagationInterceptor`, `Metadata.bearer`; any transport |
| | `AuthenticationGRPCNIOTransport` | grpc-swift-nio-transport | `CertificateAuthenticationInterceptor`; needs the NIO Posix transport, the only one that exposes the certificate |
| swift-authentication-hummingbird | `AuthenticationHummingbird` | hummingbird-auth | `BearerAuthenticationMiddleware` |
| swift-authentication-vapor | `AuthenticationVapor` | vapor | `BearerAuthenticationMiddleware` for Vapor 4 |

An `Authenticator` answers one of three ways, and every transport honours them the same way: an identity binds a `Principal`; `nil` declines, and the call continues unbound; a throw refuses, and the call fails as unauthenticated. A call with no credential never reaches the authenticator and continues anonymously.

**`<project>-core`** is the organization's layer over it: the identities, their proofs, and the setting the policies read. It is what a service imports.

| Product | Depends on | For |
| --- | --- | --- |
| `<Project>Authentication` | Authentication, AuthenticationJWT, AuthenticationX509, jwt-kit, swift-certificates, swift-service-context, swift-log | `UserIdentity`, `UserRole`, `ServiceIdentity`, `ServiceContext.user` and `.service`, the `.user` and `.service` log metadata providers, the EdDSA key initializers for `JWTIssuer<UserIdentity>` and `JWTAuthenticator<UserIdentity>`, `ServiceAuthenticator` |
| `<Project>Persistence` | `<Project>Authentication`, PersistencePostgres, grpc-swift-2 | `PostgresSettings.user(_:)` and `UserSettingsInterceptor` — the bound user as the tenant setting |
| `<Project>Testing` | `<Project>Authentication`, Persistence | `MockDatabase`, `MockUserAuthenticator` — test targets only |

The dependency graph is the design. A `<Service>Core` target links `<Project>Authentication` to name the user a use case decides on and the process that calls it, and gets the claims type, swift-service-context, and jwt-kit behind them — never a driver, never gRPC, never a server framework. The certificate library comes with jwt-kit either way. A key, a signer, a verifier, an interceptor: those reach only the executable, which builds them, and the authenticating service's token issuer.

Where does a type go? If it would make sense in a company that is not this one, in a swift-microservices package. If it names `UserIdentity`, `UserRole`, `ServiceIdentity`, the `emberfilm`-style trust domain, or `app.caller_user_id`, in `<project>-core`. Neither ships wrappers over the other's interceptors or middleware: a service builds the packages' types itself.

Because every package is consumed by tag, a source edit is invisible to every service until it is tagged and each consumer's `Package.resolved` is updated. Verify a cross-repository change before tagging by pointing a consumer at the working copy:

```sh
swift package edit <project>-core --path ../<project>-core   # resolution must succeed first
swift build
swift package unedit <project>-core
```

Edit mode needs a resolvable graph to enter and to leave. When the consumer's manifest already names a tag that does not exist yet, resolution fails and `edit` refuses. Temporarily rewrite the `.package(url:from:)` line to `.package(path:)`, build, and restore it; `swift package unedit` fails the same way, so revert the constraint, unedit, `git checkout -- Package.resolved`, then re-apply the constraint. Moving a tag after consumers resolved it invalidates SwiftPM's fingerprint store on every machine that resolved the old one; the fix is deleting `~/.swiftpm/security/fingerprints/<package>-*.json`, and the lesson is to move tags only before anything depends on them.

## One issuer, asymmetric keys

Sign with EdDSA (Ed25519). The service that authenticates users holds the private key and is the only service that can mint a token; every other service is configured with the public key, which verifies a token but cannot produce one.

Never use a shared HMAC secret. A symmetric key makes every service that can verify a token also able to forge one, which erases the distinction the architecture depends on. Key distribution, not a target boundary, is what keeps a single issuer: a service holding only the public key cannot build an issuer even when the issuer type is in scope.

## The user identity

`UserIdentity` is the token's payload itself: a `JWTPayload` whose stored properties are its claims, with plain accessors for what a use case reads.

```swift
public struct UserIdentity: JWTPayload, Equatable, Sendable {
    public let userId: UUID          // sub
    public let role: UserRole
    public let iss: IssuerClaim
    public let iat: IssuedAtClaim
    public let exp: ExpirationClaim

    public init(userId: UUID, role: UserRole, issuer: String, issuedAt: Date, expiration: Date)

    public var issuer: String { iss.value }
    public var issuedAt: Date { iat.value }
    public var expiration: Date { exp.value }

    public func verify(using algorithm: some JWTAlgorithm) throws { try exp.verifyNotExpired() }
}

public struct UserRole: RawRepresentable, Hashable, Codable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String
    public static let user: UserRole = "user"
    public static let admin: UserRole = "admin"
}
```

One type, no wire twin, no converting initializer. The subject is a `UUID` keyed to `sub`, so a token whose subject is not a user id fails to decode and never reaches a handler as an identity with no user in it; there is no other kind of token-bearing caller (see *Processes* below). The cost is that jwt-kit is linked wherever `UserIdentity` is, every Core included. That is accepted: the claims type is the identity, and nothing that signs or verifies comes with it.

`UserRole` is an open string, not an enum. An authenticator that meets a role it has no name for decodes it and grants it nothing, rather than refusing the whole token — so adding a role breaks no consumer, only the checks meant to admit it. There is no `service` role: a process is not proved by a token.

## What belongs in the token

A token answers *who is calling*. It never answers *what they may do*. Carry the authentication claims and the identity attributes a service needs in order to decide for itself — the subject, the issuer, the validity window, and a role. Keep permissions, scopes, entitlements, and feature grants out of it.

A role is a fact about a user, owned by the service that stores users. A permission is a policy, owned by whichever service enforces it. Putting `scopes: ["users:list", "orders:refund"]` in the token moves every service's policy into the one service that mints tokens: adding an RPC now means changing the issuer, and the set of things a token authorises can only be discovered by reading every consumer. Putting `role: admin` there instead lets each service answer "may an admin do this *here*?" in its own code, beside the use case that does it.

Every claim is a copy of state that can go stale. It is fixed at signing and only changes when the token is refreshed, so a demotion takes effect up to one access-token lifetime late. That is the same bound that already applies to a revoked session, and it is why the access-token expiry is kept short. It is also why the claim set should stay small: a claim nothing reads is a liability that looks like a control, and a claim everything reads is a cache nothing invalidates.

## Signing

Only the authenticating service holds the private key and builds a `JWTIssuer<UserIdentity>`, in its entry point, through the EdDSA initializer `<Project>Authentication` adds. Its token issuer, in `<Service>Core`, takes `any CredentialIssuer<UserIdentity, String>` and builds the identity itself, so `<Service>Core` holds no key even here:

```swift
package struct AccessTokenIssuer: Sendable {
    package struct Configuration: Sendable {
        package let issuer: String
        package let tokenIssuer: any CredentialIssuer<UserIdentity, String>
    }

    package func issue(userId: UUID, role: UserRole, expiration: TimeInterval) async throws -> AccessToken {
        let now = Date.now
        let identity = UserIdentity(
            userId: userId, role: role,
            issuer: configuration.issuer, issuedAt: now, expiration: now.addingTimeInterval(expiration)
        )
        return AccessToken(value: try await configuration.tokenIssuer.issue(for: identity), expirationDate: identity.expiration)
    }
}
```

The caller states who the token is for, what role they hold, and how long it lasts. `role` is the caller's to state because only the caller has looked the subject up: the issuer attests a claim, it does not know what is true of a user. `iss` and `iat` are the issuer's: an issuer is a property of the service doing the signing rather than of any one token, so stating it per call site is the same value repeated everywhere and wrong wherever it drifts.

Return the expiration beside the token rather than reading it a second time. A caller that mints a token almost always has to report when it expires, and deriving that expiry twice leaves the token and what the caller says about it as two readings of the clock that can disagree.

## Identifying a caller versus requiring one

Two separate decisions. Identifying is infrastructure and belongs in the transport packages; requiring is the handler's.

- The identifying interceptor binds the caller when a token is present and leaves the context untouched when there is none. It is applied to the RPC services that take a token — see *One RPC service per audience*.
- Requiring a caller is the handler's job: it reads `ServiceContext` and refuses with `unauthenticated` when nothing is bound.

Absent and invalid are not the same thing. A caller who presents nothing has claimed nothing; a caller whose token does not verify has made a claim that failed. Pass the first through anonymously and refuse the second with `unauthenticated`. Reading an invalid token as anonymous turns an expired token into a silent loss of privileges on an unprotected RPC and hides a misconfigured client whose credentials nothing ever looks at.

There are no shared `require…` helpers. Each producer adapter writes the one guard it needs, private to the file, because the check a handler needs is its own:

```swift
private func requireUser() throws -> UserIdentity {
    guard let user = ServiceContext.current?.user else {
        throw RPCError(code: .unauthenticated, message: "Authentication is required.")
    }
    return user.identity
}
```

On HTTP, Hummingbird ships the second half already, so the split is `BearerAuthenticationMiddleware` and `IsAuthenticatedMiddleware`; on Vapor it is `BearerAuthenticationMiddleware` and `guardMiddleware()`.

## Where the caller lives

What a call proved lives in the task's `ServiceContext` — [swift-service-context](https://github.com/apple/swift-service-context), the one request-scoped carrier the server ecosystem shares — under a key per kind of caller, for the length of the call:

- `ServiceContext.current?.user` is a `Principal<UserIdentity, String>`: the verified identity and the token that proved it. The bearer interceptor and the middleware set it.
- `ServiceContext.current?.service` is a `Principal<ServiceIdentity, Certificate>`: the process and the certificate that named it. The certificate interceptor sets it.

They are separate keys in the same context — `PrincipalKey` is generic over both the identity and the credential — so a request can carry both: a service relaying a person's call arrives with its own certificate *and* the person's token, and neither interceptor touches the other's. A handler reads whichever it is written for; a test binds one with the standard `ServiceContext.withValue`.

It is `ServiceContext` rather than a task-local of a package's own because that is the context tracing spans and logging metadata providers already read. `<Project>Authentication` ships two `Logger.MetadataProvider`s, `.user` and `.service`; a composition root passes them to `LoggingSystem.bootstrap` and every log line inside a request carries `user_id` or `service_name` with no handler naming them (see *Serve composition root* in [composition.md](composition.md)). The tenant setting the database reads travels in the same context, under `postgresSettings`, bound by `UserSettingsInterceptor` right after the user is (see *Row-level security* in [persistence.md](persistence.md)). Do not declare a `@TaskLocal` for a caller anywhere: a value that belongs to the request belongs in `ServiceContext`, under a key.

## Authorization lives in the use case

The token supplies the role and the certificate supplies the name. What that caller may do is decided inside the use case, in Swift, against the identity it was handed. Which kind of caller a use case serves is in its signature, so a handler cannot call one without the identity it needs and the compiler says so:

| Kind | Use case | Reached through | Bound by |
| --- | --- | --- | --- |
| Public | `callAsFunction(input:)` | `<Entity>PublicService` | nothing |
| User | `callAsFunction(subject: UserIdentity, input:)` | `<Entity>Service` | the bearer interceptor |
| Internal | `callAsFunction(service: ServiceIdentity, input:)` | `<Entity>InternalService` | the certificate interceptor |

A use case that serves two audiences has two overloads, and the shared work is a private method:

```swift
package func callAsFunction(subject: UserIdentity, input: GetUserByIDUseCaseInput) async throws(GetUserByIDUseCaseError) -> User {
    let id = try id(input)
    guard id == subject.userId || subject.role == .admin else {
        logger.warning("User read refused: not the subject's own row", metadata: ["userId": "\(id)"])
        throw .forbidden
    }
    return try await find(id)
}

package func callAsFunction(service: ServiceIdentity, input: GetUserByIDUseCaseInput) async throws(GetUserByIDUseCaseError) -> User {
    try await find(try id(input))
}
```

The check is in the use case rather than the handler because it is a rule about the operation, not about the transport: whoever reaches this, over whatever protocol, is held to it, and a use-case test covers it like any other guard. The refusal is a case of the use case's own error, `.forbidden`, which the producer maps to `permissionDenied`.

Distinguish the two failures. A missing caller is `unauthenticated`, because presenting a token could change the answer. A caller who is present and refused is `permissionDenied`, because presenting a different token could not. Collapsing them tells a client to go and refresh a token that was never the problem, and it will keep refreshing.

Which process may do what is decided the same way, against the `name` the use case was handed. Today every internal use case admits any named process; an allowlist, when one is wanted, is a guard in the use case, never a list in the interceptor. And nothing about authorization travels to the database: a policy isolates a tenant, and a role in SQL would be this decision written twice.

## One RPC service per audience

Split every contract by audience, in the proto package, so the interceptors apply per service rather than per method (see *Contract design* in [grpc-and-protos.md](grpc-and-protos.md)):

- `<Entity>PublicService` — RPCs that take no caller: the session-issuing ones, a sign-up, a catalogue read, a provider webhook. No interceptor.
- `<Entity>Service` — RPCs a signed-in user calls. The bearer interceptor, then on a tenant service the settings interceptor.
- `<Entity>InternalService` — RPCs another process calls. The certificate interceptor.

```swift
GRPCServer(
    transport: …,
    services: [userPublicService, userService, userInternalService],
    interceptorPipeline: [
        .apply(
            BearerAuthenticationInterceptor(authenticator: userAuthenticator),
            to: .services([<Organization>_Users_V1_UserService.descriptor])
        ),
        .apply(
            UserSettingsInterceptor(),
            to: .services([<Organization>_Users_V1_UserService.descriptor])
        ),
        .apply(
            CertificateAuthenticationInterceptor(authenticator: ServiceAuthenticator()),
            to: .services([<Organization>_Users_V1_UserInternalService.descriptor])
        ),
    ]
)
```

This is what makes the session-issuing exclusion structural. Login and refresh are reached precisely when the caller's current session is no good: a client that attaches its access token to every outgoing call sends its expired token along with the refresh request, and refusing a present-but-invalid token would refuse the one call that could replace it. On the public service no interceptor runs, so there is no method list to keep in step with the proto and nothing to drift.

An RPC that both a user and a process call appears on both services, with the use case's two overloads behind it.

## Propagating the caller

`ServerContext` carries the method descriptor and the peers, not the request metadata, so a handler has no way to reach the token it arrived with. The bearer interceptor binds the token beside the identity as the principal's credential, and `BearerPropagationInterceptor` reads it back and puts it on the outgoing call, so one token identifies the caller at every service in the chain. Forward the token unchanged; never reissue it, since only the signing service can produce another.

Apply it per user-service descriptor on the client, so a public service is dialled with nothing:

```swift
GRPCClient(
    transport: …,
    interceptorPipeline: [
        .apply(
            BearerPropagationInterceptor<UserIdentity>(),
            to: .services([<Organization>_Users_V1_UserService.descriptor])
        )
    ]
)
```

A call made outside a caller's request — startup work, a workflow Activity, a scheduled job — has nothing to forward, and the interceptor sends it out unauthenticated rather than failing. A process identifies itself on such calls with its certificate, not a token — see below.

## Processes: the certificate is the credential

A worker, a service reacting to a provider's webhook, the authenticating service reaching the users service before any caller exists — anything that calls other services with no inbound request behind it — is a principal of a second kind, and it is proved by a second mechanism. Every process in the mesh already presents one mTLS leaf on every connection it opens (*Transport security* in the delivering skill's environment reference). That certificate is the process's credential: there is no service token, no client secret, no exchange with the authenticating service, and no `service` role.

**The name is a SPIFFE ID.** Each leaf carries a URI subject alternative name, `spiffe://<trust-domain>/<process>` — `spiffe://<project>/billing-worker` — beside the DNS names a client dials. The URI is the identity and the DNS names are addresses: a process is dialled as different names in different environments, and the URI is the same in all of them. This is the workload-identity shape the industry standardised on (SPIFFE, and NIST SP 800-204's service-mesh guidance); it is what a mesh's sidecars would issue, so adopting one later changes nothing in the services.

**Reading it.** The transport has already checked that the certificate chains to the trust roots by the time the interceptor runs, so what remains is to say *who* it names. That is an `Authenticator<Certificate, ServiceIdentity>`, and it declines rather than refuses: a CA outside the process issued the credential and the TLS client presents it on every connection unasked, so there is nothing left to refuse. `SPIFFEAuthenticator` reads the URI SAN for one trust domain; `<Project>Authentication` wraps it in `ServiceAuthenticator`, which fixes the trust domain and maps the path to a `ServiceIdentity` — a `name`, `billing-worker`. A leaf without the URI identifies as nothing: reissue it.

**Being bound says only that a known process called.** Every process holds a valid certificate, the API gateway included. A call with no certificate, or from a peer the authenticator has no name for, arrives unbound rather than refused — the transport rejected the invalid ones, and an unlisted peer is a valid one this service simply does not admit. There is deliberately no allowlist in the interceptor; which process may do what is the use case's decision, made against the `name` it was handed, like every other authorization rule. A certificate proves a credential, never a permission.

**A process forwards nothing.** Its certificate is on the connection, so a client that speaks as the process carries no interceptor at all. A process that also relays a person's call does so through the bearer interceptor on the same client, applied to the user services alone; the two identities never compete for a header.

The same shape applies to the issuer: the authenticating service reaches the users service on behalf of a caller who has no token yet, through the users' internal service, as itself. It could sign a token for itself, since it holds the key; do not. One mechanism for every process keeps the issuer from being the one process that authenticates differently from the rest.

## The three rules

Every flow in the system is a combination of the same parts. A user is proved by a token, bound as `ServiceContext.user`, and handed to a use case as `subject:`. A process is proved by its certificate, bound as `ServiceContext.service`, and handed to a use case as `service:`. Every gRPC connection is mTLS, so a process is always identifiable; whether anything reads that is per RPC service.

| Flow | Identity at the destination | Bound by | Use case | Database |
| --- | --- | --- | --- | --- |
| Anonymous → gateway → service | none | nothing | `input:` on the public service | tenant-scoped with no user, or a table without tenants |
| User → gateway → service | the user | bearer interceptor on the user service | `subject:input:` | tenant-scoped, narrowed to the user |
| User → gateway → service A → service B | the same user, at B | B's bearer interceptor, reading the token A forwarded | `subject:input:` at B | B's tenant-scoped |
| Administrator → service | the user, checked for `.admin` in the use case | bearer interceptor | `subject:input:` | unscoped |
| Service A → service B, no user | process A, at B | certificate interceptor on B's internal service | `service:input:` with the user id in the input | B's unscoped |
| Request → workflow → worker, own data | none; the input came from the workflow | nothing, in-process | `input:` built only in the worker | the worker's own, unscoped |
| Worker → another service | the worker process | certificate interceptor on the internal service | `service:input:` | that service's unscoped |
| External provider → service | the provider, by its signature | the handler's signature check | `input:` on the public service | per what it touches |

Three rules make the table hold. Each answers a question that comes up every time a handler is written.

1. **"I am handing work to a worker. What do I give it?"** The user's id, never their token. A token is short-lived proof that a person is present right now; a workflow can run for days, when that person is gone and the token is dead. So the worker does not pretend to be the user. It is its own process, doing a job that mentions a user — its use cases take `input:` with a user id inside, and the worker signs in to nothing.
2. **"Service A is handling a user's request and needs service B. Who does B see?"** The user. A forwards the user's token unchanged, B verifies it, and B treats the call exactly as if the user had called it directly. A does not become a new principal in the middle. B sees a process instead of a user only when there was no user to begin with: a workflow or a webhook started the work, not a person.
3. **"Who decides whether this call is allowed?"** Two things, in two places. Which *kind* of caller must be present is decided by which RPC service the method lives on: a public service checks nothing, a user service binds a token, an internal service binds a certificate. What that caller may *do* — which rows, which action, admin or not — is decided inside the use case, in Swift, against the `subject:` or `service:` it was handed.

Put together: a person's identity travels with their request and stops when the request stops. Anything that outlives a request runs as a process. The RPC service establishes who is there, and the use case decides what they get. The database side of the table — which role each row of it connects as — is in *Row-level security* in [persistence.md](persistence.md).

## Reading the credential

`Metadata.bearer` in `AuthenticationGRPC` parses `authorization` on gRPC; Hummingbird and Vapor each read the header with their own parser. All three keep the same rules:

- Match the scheme without regard to case, as RFC 7235 defines it. Requiring exactly `Bearer` reads a `bearer` header — which grpc-web clients and proxies send — as no credential at all, and an unauthenticated caller is far harder to notice than a rejected one.
- Take the first `authorization` entry, not the first that happens to parse. Taking the latter lets a caller hide a second credential behind one the service ignores.
- Setting the token replaces rather than adds. A second entry leaves which one the receiver reads down to ordering.

## Key material in configuration

Configuration carries the path to a key, not the key itself. The composition root opens the file, through an extension on the key type in the executable's `Configuration` folder:

```swift
extension EdDSA.PublicKey {
    /// `Serve` scopes this reader to `jwt`, so the variable is `JWT_PUBLIC_KEY_PATH`.
    init(config: ConfigReader) throws {
        let publicKeyPath = config.string(forKey: "publicKeyPath", default: "/run/secrets/jwt-public")
        let publicKey = try String(contentsOfFile: publicKeyPath, encoding: .utf8)
        try self.init(pem: publicKey)
    }
}

let userAuthenticator = await JWTAuthenticator<UserIdentity>(publicKey: try EdDSA.PublicKey(config: config.scoped(to: "jwt")))
```

The authenticating service has the private-key twin, `EdDSA.PrivateKey+ConfigReader.swift`, reading `privateKeyPath` as required. Both sit beside `PostgresConfiguration.swift` and `TransportSecurity+ConfigReader.swift`.

A path is what the surrounding libraries already take. `TLSConfig.CertificateSource.file(path:format:)` and `PrivateKeySource.file(path:format:)` in grpc-swift, and `NIOSSLCertificate.fromPEMFile` in NIOSSL, are handed a path and open it themselves, so the mTLS leaf every service presents is configured exactly like the signing key — the same folder, the same file shape. Nothing about a path resists an environment variable, which is the whole reason a PEM document was ever base64-encoded into one.

It matters most for a private key. An environment variable is readable from `/proc/<pid>/environ`, reported by the container runtime's inspect command, and inherited by every child process; a mounted file is none of those. It also keeps the material from becoming a configuration value at all, which is what an access reporter would otherwise be free to log.

Fail loudly when the file is unreadable, naming both the key and the path. An absent mount, a wrong path, and the wrong file mode are different deployment mistakes with different fixes, and a failure that names neither leaves the operator to guess.

If you inherit a system that carries the encoded document in the variable instead, the decoding order is load-bearing: test the input for a `-----BEGIN` header *before* attempting base64, never the decoded output. Base64 decoding tolerates every character a PEM is made of, so decoding a raw PEM produces plausible-looking rubbish rather than failing, and whether it survives depends on the document's length modulo four. Prefer migrating it to a path.

Do not bundle a key as a SwiftPM resource: it is not a leak for a public key, but it bakes the value into the image and makes rotation a rebuild.

Ship a `scripts/generate-keys.sh` with the issuing service that writes the pair as PEM files and refuses to overwrite an existing pair without `--force`, since rotating invalidates every access token in flight. The private key has to land on disk for a container to mount it, so protect it there: create the directory `0700`, set `umask 077` *before* `openssl` writes so the key is never briefly world-readable between creation and `chmod`, and add the directory to `.gitignore`.

jwt-kit is pinned below 5.7.0 in swift-authentication-jwt, `<project>-core`, and every service: 5.7.0's manifest turns warnings into errors, and Xcode passes `-suppress-warnings` to every package dependency, which the compiler refuses to combine — `swift build` passes and the Xcode build does not. Do not raise the pin until jwt-kit moves the setting out of its manifest.

## Rotation

Rotating the signing keys means generating a new pair and restarting every service. Access tokens signed by the old key stop verifying and clients recover on their next refresh, provided refresh tokens are database rows rather than signed tokens. Rotating a process's identity is reissuing its leaf and restarting it, the same as any certificate. How keys and certificates are mounted is the delivering skill's subject.
