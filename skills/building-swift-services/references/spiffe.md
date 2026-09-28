# SPIFFE workload authentication

Use this reference when adopting `AuthenticationSPIFFE` and `AuthenticationSPIFFEGRPC`.
Configure the trust domain, workload identity, and expected peers explicitly in each application.

## Package boundaries

- `AuthenticationSPIFFE`: strict `SPIFFEID`, immutable domain-specific `SPIFFETrustBundle`,
  full-chain `SPIFFEAuthenticator`. Verification proves claims; TLS proves key possession.
- `AuthenticationSPIFFEGRPC` (in swift-authentication-grpc): `SPIFFETransportSecurity` and
  `SPIFFEAuthenticationInterceptor`. Generic bearer/certificate products remain independent.
- Organization authentication module: `ServiceIdentity` retaining `spiffeID: SPIFFEID`, a
  mapping initializer, and `ServiceContext.service` under
  `PrincipalKey<ServiceIdentity, SPIFFEAuthenticator.Verification>`.
- Use cases: explicit per-operation service permissions, denied by default.

## Composition

Construct one `SPIFFETransportSecurity` per local identity with `try await`, supplying
`certificateChain: [Certificate]`, `privateKey: Certificate.PrivateKey`, and a
`SPIFFETrustBundle(trustDomain:authorities:)` loaded from trusted configuration. Authorities
are never peer-supplied and never combined across foreign domains.

The server uses `try security.serverTransportSecurity()` and
`SPIFFETransportSecurity.serverConfiguration` (five-minute connection age, thirty-second grace;
adapt to the credential lifetime and revocation objective). Protected services apply:

```swift
SPIFFEAuthenticationInterceptor(
    security: security,
    identity: ServiceIdentity.init(spiffeID:)
)
```

Each outgoing client uses `try security.clientTransportSecurity(expectedServer:)`, with the
exact configured upstream `SPIFFEID`. Do not merely accept any server under a trusted root.
The SPIFFE URI replaces hostname matching for these connections; unrelated external endpoints
keep their existing hostname-verified TLS. No custom NIOSSL verification code belongs in projects.

## Lifecycle

An external provider performs attestation and renewal. Its structured lifecycle task delivers
complete updates to `try await security.update(certificateChain:privateKey:bundle:)` in order.
The adapter verifies key match and local identity before atomically publishing all material;
failed updates retain the last still-valid snapshot. `security.isReady` gates readiness.
This is a renewal sink, not a Workload API client; do not claim issuer integration without one.

Use short-lived SVIDs, provider renewal retries bounded by expiry, expiry/renewal alerts, and
root overlap. Do not use the one-shot development CA and year-long leaves as a production
identity lifecycle. Keep private keys access-restricted and outside images or environment values.

Trust removal is checked on subsequent protected RPCs even on existing connections. In an
emergency call `security.revoke()` and close the owning server/client transports to terminate
existing streams. Finite connection age, grace, and RPC deadlines bound normal reauthentication.
Rotation cannot silently change the local workload ID; use a new adapter/process for reassignment.

## Verification

Use published package tags and certificates that meet the X.509-SVID profile. Cover an
actual mTLS call, wrong expected server, missing/foreign client certificate, leaf/root renewal,
provider outage through expiry, and root removal on an existing connection. Reject invalid
chains and identities without falling back to parsing a bare leaf.
