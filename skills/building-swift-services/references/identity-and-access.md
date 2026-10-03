# Identity and access

Use mTLS to admit service connections and user JWTs to authorize user operations. Keep those responsibilities separate from business invariants and database tenant isolation.

## Contents

- The packages
- One issuer, asymmetric keys
- The user identity
- Identifying a caller versus requiring one
- Where the caller lives
- Authorization lives in the use case
- One RPC service per audience
- Propagating the caller
- Validation at every process boundary
- Processes: the certificate is the credential
- The three rules
- Key material in configuration
- Rotation

## The packages

| Package | Responsibility |
| --- | --- |
| swift-authentication | Generic `Authenticator`, `CredentialIssuer`, `Principal`, and `PrincipalKey` |
| swift-authentication-jwt | Issue and verify user JWTs through jwt-kit |
| swift-authentication-grpc | Bind user bearer principals and forward their original credentials |
| swift-authentication-hummingbird / swift-authentication-vapor | Bind user principals in HTTP request contexts |
| grpc-swift-nio-transport | TLS handshakes, explicit CA trust, and peer certificate verification |
| swift-nio-extras, product `NIOCertificateReloading` | `TimedCertificateReloader` for updated certificate/key files |

The organization module `<Project>Authentication` owns `UserIdentity`, `UserRole`, user context accessors, and the `.user` logging metadata provider. It may add JWT key conveniences. It does not map transport certificates into application principals. Keep configuration adapters in the executable unless the underlying library already offers a native reader.

## One issuer, asymmetric keys

The authentication service holds the private signing key. Other services hold only the public verification key. A gateway forwards the original user token; it does not mint a replacement. EdDSA is the default here. Keep keys mounted as files and configure their paths.

## The user identity

`UserIdentity` is the organization's `JWTPayload`. Use `sub` for the user UUID and claims for role, issuer, audience when applicable, issue time, and expiration. Its `verify(using:)` enforces the claims the deployment depends on. Keep mutable business state, entitlements, and secrets out of the token; use cases read authoritative state from the owner.

An open string `UserRole` can expose `.user` and `.admin` constants without turning an unknown role into administrator access. A caller's role is a user authorization input, not a database role.

## Identifying a caller versus requiring one

An authenticator receives a credential and returns an identity or throws. The bearer interceptor or middleware rejects a presented invalid token. With no credential it continues unbound. A user handler requires a verified identity and returns `unauthenticated` (HTTP 401) when absent.

Keep login, refresh, registration, and provider webhooks outside user bearer authentication. These operations check their own passwords, refresh tokens, challenges, or signatures. An expired access token attached by a client must not block the operation that replaces it.

## Where the caller lives

The bearer transport binds `Principal<UserIdentity, String>` under `PrincipalKey` in `ServiceContext`. The credential is retained for outgoing propagation. The organization may expose this as `ServiceContext.user`; do not create another task-local carrier.

Handlers pass the identity to use cases as `subject:`. Core never reads `ServiceContext`. Log the local process using the logger's service label and the verified user through `.user`; do not invent a remote process identity from request metadata.

On tenant operations, the user settings interceptor or middleware follows bearer authentication and binds transaction-local `app.caller_user_id`. See [persistence.md](persistence.md).

## Authorization lives in the use case

| Audience | Use-case signature | Access boundary |
| --- | --- | --- |
| Public | `callAsFunction(input:)` | Operation-specific credentials or proofs |
| User / administrator | `callAsFunction(subject: UserIdentity, input:)` (omit empty input) | Verified user; owning use case checks role and resource access |
| Internal service / worker | `callAsFunction(input:)` | Peer admitted by transport mTLS; owning use case checks business invariants |

Every peer admitted by the listener's configured CA trust can call its internal operations. This is a deliberate trust boundary, not per-workload authorization. Keep backend listeners private and gateway routes limited to public and user operations. If admission requirements later differ by workload, revisit the trust/authorization design explicitly.

An HTTP route collection or verb may additionally be protected by `AdminRequestContext` or equivalent middleware using only verified JWT role claims, without database lookups. This early gate supplements the owning use case; it does not replace resource or business authorization.

A self-only operation derives its user ID from `subject`, never a business input. Explicit permission predicates are checked before side effects and throw the use case's own `.forbidden`; deriving a self-only ID from the subject needs no redundant equality guard. The producer translates that to `permissionDenied` (HTTP 403). Internal input still requires valid relationships, legal state transitions, consistency, and idempotency. A user ID in internal input identifies a resource; it is not a verified user principal.

When two audiences share business work, expose a user overload and an input-only internal overload with a private common implementation. Do not let the user overload skip its permission check.

## One RPC service per audience

Split protobuf descriptors into `<Entity>PublicService`, `<Entity>Service`, and `<Entity>InternalService`, omitting unused audiences. Apply bearer authentication and then tenant settings only to user descriptors:

```swift
interceptorPipeline: [
    .apply(
        BearerAuthenticationInterceptor(authenticator: userAuthenticator),
        to: .services([UserService.descriptor])
    ),
    .apply(
        UserSettingsInterceptor(),
        to: .services([UserService.descriptor])
    ),
]
```

Internal descriptors have no application authentication interceptor. Their listener still requires mTLS. Public backend descriptors also remain behind that listener, with their own operation-specific proofs.

## Propagating the caller

Apply `BearerPropagationInterceptor<UserIdentity>()` only to upstream user descriptors. It sends the original credential from the bound principal. The receiver verifies that JWT independently. It is not applied to public or internal descriptors, and a worker carries no user token.

Bearer parsing takes the first authorization entry, matches the scheme case-insensitively, and replaces existing authorization metadata when forwarding a bound credential. Use the packages' parsers rather than duplicating them.

## Validation at every process boundary

Every service-to-service connection requires mTLS. Clients verify the server chain and destination hostname; listeners require a client certificate against explicit roots. User RPCs additionally verify the original JWT and authorize the operation in the owning use case. Request fields and asserted metadata are not substitutes for that verification.

Inside a monolith, verify the user at the transport and pass `subject:` to local calls. No TLS connection exists between modules in one process.

## Processes: the certificate is the credential

Services and workers call internal RPCs over mTLS without an application token or certificate-to-principal mapping. DNS SANs cover the names clients dial. No URI SAN is required by this application model. Certificate issuance and trust determine which peers are admitted.

Temporal always uses its own certificate/key pair, trust configuration, and reloader under `temporal.tls`, distinct from service credentials under `tls`. The same scoped configuration adapters serve both. See [composition.md](composition.md#transport-security-factories) for the Swift lifecycle and the delivery skill for provisioning.

## The three rules

1. Authorize a user-triggered workflow at the initiating request. Put resource IDs and durable business input in the workflow, never the user's token.
2. Forward the original JWT when a service continues a user RPC through another user descriptor. Verify it again at the receiver.
3. Let transport trust admit internal peers. Internal handlers accept input directly; use cases enforce business invariants over the internal or worker database scope without impersonating a user.

## Key material in configuration

Read configuration in executable-local type extensions, using only a scoped `ConfigReader` for configuration values. Use native library readers first. Paths belong in application defaults with environment overrides; the cryptographic library opens the configured files. Missing or unusable required material fails startup.

The application owns paths such as `/run/secrets/jwt-public`, `/run/tls/cert.pem`, and `/run/temporal-tls/cert.pem`. Reusable readers should not guess which deployment or trust scope is calling them. See [configuration.md](configuration.md).

## Rotation

JWT key rotation uses an overlap of verification keys and a new signing key; retain the old verification key until issued tokens expire. A deployment that replaces a single key and restarts verifiers invalidates outstanding tokens, so document that behavior if it is intentionally used.

TLS leaf renewal is independent. Prime and run `TimedCertificateReloader` with the transports; it loads renewed certificate/key files for new handshakes and retains the last usable pair after a failed update. Existing connections need reconnection or bounded draining. CA trust changes require rebuilding transports or a rolling restart with overlapping trust. See the delivery skill for Smallstep issuance, renewal, and rekeying.
