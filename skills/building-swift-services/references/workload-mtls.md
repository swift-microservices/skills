# Workload authentication with native mTLS

## Public packages

`swift-authentication-x509` provides `AuthenticationX509`: `WorkloadIdentity` and
`WorkloadCertificateAuthenticator`. `swift-authentication-grpc` provides the transport-independent
bearer product `AuthenticationGRPC` and the NIO certificate product `AuthenticationGRPCNIOTransport`.
Use tagged dependencies matching these APIs; do not invent transport factories or provider APIs.

```swift
import AuthenticationX509
import AuthenticationGRPCNIOTransport

let worker = try WorkloadIdentity(uri: "https://identity.production.example/workloads/billing-worker")
let authenticator = try WorkloadCertificateAuthenticator(authority: "identity.production.example")
let interceptor = CertificateAuthenticationInterceptor(authenticator: authenticator)
```

An organization may wrap these in `ServiceIdentity` and `ServiceAuthenticator`. Delegate validation
to the shared package; do not duplicate URI parsers or introduce a name-to-identity dictionary.

## Independent trust decisions

1. Native required mTLS verifies the complete peer chain against explicit environment CA roots,
   certificate purpose and key possession. Clients use `.fullVerification` and the actual upstream
   DNS name. A caller URI is not a substitute for server DNS verification.
2. `WorkloadCertificateAuthenticator` checks leaf validity, exactly one HTTPS URI SAN, and the
   explicitly configured identity authority. DNS SANs may coexist. It never fetches the URI or
   authenticates a certificate passed without verified TLS.
3. `CertificateAuthenticationInterceptor` binds `Principal<WorkloadIdentity, Certificate>`.
   It continues unbound if a certificate is absent or an authenticator declines. Protected internal
   handlers must require the principal and return `unauthenticated` when it is missing. Throws from
   the authenticator are mapped to `unauthenticated`.
4. Use cases compare complete identities before effects. A CA membership, authority membership,
   path suffix, display name or metadata header alone grants no operation permission.

## Composition and renewal

```swift
let reloader = try TimedCertificateReloader.makeReloaderValidatingSources(
    configuration: .init(
        refreshInterval: .seconds(60),
        certificateSource: .init(location: .file(path: chainPath), format: .pem),
        privateKeySource: .init(location: .file(path: keyPath), format: .pem)
    )
)
let serverTLS: HTTP2ServerTransport.Posix.TransportSecurity = try .mTLS(certificateReloader: reloader) {
    $0.trustRoots = trustedRoots
}
let clientTLS: HTTP2ClientTransport.Posix.TransportSecurity = try .mTLS(certificateReloader: reloader) {
    $0.trustRoots = trustedRoots
    $0.serverCertificateVerification = .fullVerification
}
var serverConfig = HTTP2ServerTransport.Posix.Config.defaults
serverConfig.connection.maxAge = .seconds(300)
serverConfig.connection.maxGraceTime = .seconds(30)
```

Import/link `NIOCertificateReloading` from swift-nio-extras and `GRPCNIOTransportHTTP2Posix` directly.
Run the reloader alongside transports in the existing `ServiceGroup`; creating it only primes the
initial pair. Validate initial chain, matching key, expected local URI and remaining validity before
serving. Swift certificate path validation must include a policy recognizing critical SANs.
Do not disable extension checks or copy arbitrary peer roots to make startup pass.

The external issuer/renewal process obtains certificates and atomically replaces the chain in a
stable directory; the reloader does not renew or attest workloads. Keep the key and roots unchanged
for routine leaf renewal. Mount the directory, not an individual file that retains an old inode.
Restrict each application to its credentials and give only its renewal process write access.

The reloader retains the last successful pair after parse/read/key errors. It does not check your
expected URI, CA trust or full validity policy before loading. A parseable invalid replacement can
break new connections; peers reject it. Loaded-file health is not proof of peer acceptance. Monitor
issuer availability, publication errors, remaining validity, loaded/served serials and handshakes.

Expired leaves fail new TLS handshakes; the authenticator also rejects expired caller leaves on
subsequent protected RPCs over existing connections. Existing streams and TLS sessions are not
continuously revalidated. Renewal does not cancel an in-flight call. Bound connection age/grace and
RPC deadlines. Root rotation requires rebuilding transports, with an explicitly managed overlap.
Emergency revocation requires closing active listeners, streams and client transports. Do not claim
that changing a file immediately revokes established sessions.

Temporal credentials and trust remain separate from internal workload credentials. Use the SDK's
native `.mTLS(certificateReloader:)`, full hostname verification and issuer-specific renewal.
Workers authenticate as themselves; workflow user IDs are durable business data, not credentials.
