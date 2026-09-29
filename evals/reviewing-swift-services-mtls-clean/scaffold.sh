#!/bin/bash
set -euo pipefail
cat > REVIEW-SCOPE.md <<'FIXTURE'
# Review boundary

These are read-only excerpts, not a runnable package. Do not build. Missing entrypoint, handlers,
service registration, repositories, deployment files and tests are intentional omissions.
The supplied platform contract issues exactly one HTTPS URI and assigned DNS SANs per workload,
uses independent production roots, and mounts each directory read-only into its workload. A separate
renewal process owns issuance and atomic chain replacement while preserving key and roots. Startup
validates chain/key/local identity and primes the reloader; ServiceGroup runs it. Internal handlers
require the bound certificate principal. Server age/grace are 300/30 seconds, and RPCs have deadlines.
Only the full production entitlements-worker identity can fulfill purchases, never the audit worker
or a staging worker. billing.internal.acme.example is the configured DNS target. The HTTPS identity
URI is an identifier, not an HTTP endpoint. Readiness here means file-load success and leaf validity,
not proof of peer acceptance. Issuer/expiry/handshake alerts are supplied by platform monitoring.
Trust roots are fixed per transport; root rollout recreates transports. The emergency callback closes
listeners, active streams and outgoing connections. Review only the shown behavior and these contracts.
FIXTURE
mkdir -p Sources/Ledger/Serve
cat > Sources/Ledger/Serve/Serve.swift <<'FIXTURE'
import AuthenticationX509
import AuthenticationGRPCNIOTransport
import GRPCNIOTransportHTTP2Posix
import NIOCertificateReloading

let authenticator = try WorkloadCertificateAuthenticator(authority: "identity.prod.acme.example")
let interceptor = CertificateAuthenticationInterceptor(authenticator: authenticator)

func billingTLS(reloader: TimedCertificateReloader, roots: TLSConfig.TrustRootsSource) throws -> HTTP2ClientTransport.Posix.TransportSecurity {
    try .mTLS(certificateReloader: reloader) {
        $0.trustRoots = roots
        $0.serverCertificateVerification = .fullVerification
    }
}
// Dial target is billing.internal.acme.example. No authority override is used.
FIXTURE
mkdir -p Sources/Ledger/UseCases
cat > Sources/Ledger/UseCases/FulfillPurchaseUseCase.swift <<'FIXTURE'
import AuthenticationX509

typealias ServiceIdentity = WorkloadIdentity
let allowedWorker = try! WorkloadIdentity(uri: "https://identity.prod.acme.example/workloads/entitlements-worker")
enum FulfillmentError: Error { case forbidden }
struct FulfillPurchaseUseCase: Sendable {
    let repository: any FulfillmentRepository
    func callAsFunction(service: ServiceIdentity, purchaseID: String) async throws {
        guard service == allowedWorker else { throw FulfillmentError.forbidden }
        try await repository.markFulfilled(purchaseID)
    }
}
FIXTURE
mkdir -p Sources/Ledger/Identity
cat > Sources/Ledger/Identity/IdentityRuntime.swift <<'FIXTURE'
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import X509

func ready(leaf: Certificate, lastLoadSucceeded: Bool) -> Bool {
    lastLoadSucceeded && leaf.notValidBefore <= Date.now && Date.now < leaf.notValidAfter
}

func emergencyRevoke(closeTransports: @Sendable () async -> Void) async {
    await closeTransports()
}
FIXTURE
