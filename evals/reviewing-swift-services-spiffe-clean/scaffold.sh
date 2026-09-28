#!/bin/bash
set -euo pipefail
cat > Package.swift <<'FIXTURE'
// swift-tools-version: 6.3
import PackageDescription
let settings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]
let package = Package(
    name: "acme-ledger",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "ledger", targets: ["Ledger"])],
    dependencies: [
        .package(url: "https://github.com/swift-microservices/swift-authentication-spiffe.git", from: "0.2.0"),
        .package(url: "https://github.com/swift-microservices/swift-authentication-grpc.git", from: "0.3.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.10.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.20.0"),
    ],
    targets: [.executableTarget(name: "Ledger", dependencies: [
        .product(name: "AuthenticationSPIFFE", package: "swift-authentication-spiffe"),
        .product(name: "AuthenticationSPIFFEGRPC", package: "swift-authentication-grpc"),
        .product(name: "GRPCNIOTransportHTTP2Posix", package: "grpc-swift-nio-transport"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "X509", package: "swift-certificates"),
    ], swiftSettings: settings)],
    swiftLanguageModes: [.v6]
)
FIXTURE
cat > REVIEW-SCOPE.md <<'FIXTURE'
# Review boundary

This is an excerpt-only identity/composition fixture. It is not a complete executable.
Generated service registration, entrypoint, logger hooks, repository protocol/implementation,
business types, HTTP probes, tests, database code, and deployment manifests are intentionally
omitted. Their absence is not a finding. Review only the supplied behavior; do not build.

The platform contract supplies coherent generations from an attesting provider. Startup creates
one SPIFFETransportSecurity from the local chain/key and the production domain's trusted roots.
The same instance is passed to every supplied function. Startup checks security.id == localID.
The provider scopes roots by domain, serializes output, retries only while usable credentials
remain, and reports expiry/renewal alerts. The lifecycle owns the update task and cancels it
on shutdown. RPCs use finite deadlines; the server configuration bounds connection age/grace.

Only the production entitlements-worker may fulfill purchases. Staging has the same path
under staging.acme.example. Billing's expected identity is the billingID constant; localID is
this service's own identity. Readiness calls ready(security:). The emergency endpoint invokes
emergencyRevoke with a callback that closes the listener, active streams, and client transports.
A live RPC must be terminated during emergency revocation, not merely denied on its next call.

Authorities overlap A+B while workloads renew; after A is removed, protected RPCs must use
current trust. URI-only SVIDs are intentional. No custom hostname verifier is required for
these SPIFFE clients. Unrelated external HTTPS integrations are outside the fixture.
FIXTURE
mkdir -p Sources/Ledger/Serve
cat > Sources/Ledger/Serve/Serve.swift <<'FIXTURE'
import AuthenticationSPIFFE
import AuthenticationSPIFFEGRPC
import GRPCCore
import GRPCNIOTransportHTTP2Posix

let localID = try SPIFFEID(uri: "spiffe://prod.acme.example/ledger")
let billingID = try SPIFFEID(uri: "spiffe://prod.acme.example/billing")

func makeServer(security: SPIFFETransportSecurity) throws {
    let transport = HTTP2ServerTransport.Posix(
        address: .ipv4(host: "127.0.0.1", port: 50051),
        transportSecurity: try security.serverTransportSecurity(),
        config: SPIFFETransportSecurity.serverConfiguration
    )
    let interceptor = SPIFFEAuthenticationInterceptor(
        security: security, identity: ServiceIdentity.init(spiffeID:)
    )
    // The application registers this interceptor on LedgerInternalService.
    registerInternalServer(transport: transport, interceptor: interceptor)
}

func billingTLS(security: SPIFFETransportSecurity) throws
    -> HTTP2ClientTransport.Posix.TransportSecurity {
    try security.clientTransportSecurity(expectedServer: billingID)
}
FIXTURE
mkdir -p Sources/Ledger/UseCases
cat > Sources/Ledger/UseCases/FulfillPurchaseUseCase.swift <<'FIXTURE'
import AuthenticationSPIFFE

struct ServiceIdentity: Sendable {
    let spiffeID: SPIFFEID
}

enum FulfillmentError: Error { case forbidden }

struct FulfillPurchaseUseCase: Sendable {
    let repository: any FulfillmentRepository
    let allowedWorker = try! SPIFFEID(uri: "spiffe://prod.acme.example/entitlements-worker")

    func callAsFunction(service: ServiceIdentity, purchaseID: String) async throws {
        guard service.spiffeID == allowedWorker else { throw FulfillmentError.forbidden }
        try await repository.markFulfilled(purchaseID)
    }
}
FIXTURE
mkdir -p Sources/Ledger/Identity
cat > Sources/Ledger/Identity/IdentityRuntime.swift <<'FIXTURE'
import AuthenticationSPIFFE
import AuthenticationSPIFFEGRPC
import X509

struct IdentityGeneration: Sendable {
    let certificateChain: [Certificate]
    let privateKey: Certificate.PrivateKey
    let bundle: SPIFFETrustBundle
}

// Invoked as a child of the application's structured lifecycle. Provider owns retry/alerts.
func applyGenerations(_ generations: AsyncStream<IdentityGeneration>,
                      security: SPIFFETransportSecurity) async throws {
    for await generation in generations {
        do {
            try await security.update(
                certificateChain: generation.certificateChain,
                privateKey: generation.privateKey,
                bundle: generation.bundle
            )
        } catch {
            recordRenewalFailure(error)
        }
    }
}

func ready(security: SPIFFETransportSecurity) -> Bool {
    security.isReady
}

// Complete emergency response; the callback closes listener, active streams, and clients.
func emergencyRevoke(security: SPIFFETransportSecurity,
                     closeTransports: @Sendable () async -> Void) async {
    security.revoke()
    await closeTransports()
}
FIXTURE
