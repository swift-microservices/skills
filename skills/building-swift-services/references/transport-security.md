# Transport security

The configuration-backed factories that build a listener's or a client's transport security over a certificate reloader. Where each root creates its reloaders and calls these factories is in [composition.md](composition.md).

## Contents

- [Transport security factories](#transport-security-factories): the client and server mTLS factories, server TLS for a client-facing listener, connection age and keepalive, and a client's bounded wait for its connection


## Transport security factories

Configure service connections with the `tls` reader; each scope has its own certificate/key pair and trust bundle from application defaults, and adapters accept a reader, not a directory or default-path argument ([configuration.md](configuration.md)). Declare `NIOCertificateReloading` from swift-nio-extras and `GRPCServiceLifecycle` from grpc-swift-extras directly in the executable. Prime one `TimedCertificateReloader` per credential pair before constructing any transport, as both roots above do; `makeReloaderValidatingSources` loads and validates the initial pair without starting the reload loop. Own the reloader exactly once in the same `ServiceGroup` as the transports, and share it across clients and the listener only when the pair supports both purposes.

```swift
// Sources/<Service>/Configuration/HTTP2ClientTransport.Posix.TransportSecurity+ConfigReader.swift
import Configuration
import GRPCNIOTransportHTTP2
import NIOCertificateReloading

extension HTTP2ClientTransport.Posix.TransportSecurity {
    static func mTLS(config: ConfigReader, certificateReloader: any CertificateReloader) throws -> Self {
        let trustRootsPath = try config.requiredString(forKey: "trustRootsPath")
        return try .mTLS(certificateReloader: certificateReloader) {
            $0.trustRoots = .certificates([.file(path: trustRootsPath, format: .pem)])
            $0.serverCertificateVerification = .fullVerification
        }
    }
}
```

```swift
// Sources/<Service>/Configuration/HTTP2ServerTransport.Posix.TransportSecurity+ConfigReader.swift
import Configuration
import GRPCNIOTransportHTTP2
import NIOCertificateReloading

extension HTTP2ServerTransport.Posix.TransportSecurity {
    static func mTLS(config: ConfigReader, certificateReloader: any CertificateReloader) throws -> Self {
        let trustRootsPath = try config.requiredString(forKey: "trustRootsPath")
        return try .mTLS(certificateReloader: certificateReloader) {
            $0.trustRoots = .certificates([.file(path: trustRootsPath, format: .pem)])
            $0.clientCertificateVerification = .noHostnameVerification
        }
    }
}
```

Server-side `.noHostnameVerification` still requires and verifies a client certificate against explicit trust; clients retain full chain and hostname verification. That is every internal listener.

A client-facing listener — apps or partners behind the edge proxy — presents the same leaf and requires no client certificate; the bearer interceptor identifies its callers. Add it to the same file:

```swift
extension HTTP2ServerTransport.Posix.TransportSecurity {
    /// Client-facing: server-side TLS the edge proxy verifies; callers are identified by bearer JWT.
    static func serverTLS(certificateReloader: any CertificateReloader) throws -> Self {
        try .tls(certificateReloader: certificateReloader) {
            $0.clientCertificateVerification = .doNotVerify
        }
    }
}
```

An HTTP listener gets the same with HummingbirdTLS: `server: try .tls(.http1(), tlsConfiguration: .makeServerConfiguration(certificateReloader: certificateReloader))`. The leaf's DNS SANs include the name the proxy dials. No listener has a plaintext mode.

Server connection settings, including keepalive, come from the `grpc.server` reader:

```swift
// Sources/<Service>/Configuration/HTTP2ServerTransport.Posix.Config+ConfigReader.swift
import Configuration
import GRPCNIOTransportHTTP2

extension HTTP2ServerTransport.Posix.Config {
    init(config: ConfigReader) {
        let maxConnectionAge = config.int(forKey: "maxConnectionAgeSeconds", as: Duration.self, default: .seconds(300))
        let connectionGraceTime = config.int(forKey: "connectionGraceTimeSeconds", as: Duration.self, default: .seconds(30))
        self = .defaults {
            $0.connection.maxAge = maxConnectionAge
            $0.connection.maxGraceTime = connectionGraceTime
            // Accept idle client pings through the service load balancer.
            $0.connection.keepalive.clientBehavior = .init(minPingIntervalWithoutCalls: .seconds(60), allowWithoutCalls: true)
        }
    }
}
```

Choose the connection age below the certificate's renewal budget so connections re-handshake onto renewed leaves. The reloader changes the leaf pair used on new handshakes; it does not issue certificates, refresh a trust bundle, or re-authenticate existing connections, and a failed update keeps the last usable pair. Issuance, renewal, expiry monitoring, and CA rotation are the delivery skill's ([environment reference](../../delivering-swift-services/references/environment.md#transport-security-the-certificate-volume)).

**Every client waits for the connection, bounded by a deadline.** A call made while its channel is not ready fails fast by default, which a caller hits after an idle period, a peer restart, or a rolling deploy. Set *wait-for-ready* once, client-wide, through the empty-service global `MethodConfig` bucket, with a `timeout` so a down upstream still fails:

```swift
extension ServiceConfig {
    static let defaults = ServiceConfig(
        methodConfig: [
            MethodConfig(
                names: [MethodConfig.Name(service: "")],  // "": every method of every service
                waitForReady: true,
                timeout: .seconds(15)
            )
        ]
    )
}
```

Pass it as `serviceConfig:` to every client's `.http2NIOPosix`, beside the mTLS factory. A call's `CallOptions` fill only fields the call sets, so `ServiceConfig` is the base default and `CallOptions` the per-RPC override. `GRPCServer` takes no service config.

Temporal has its own credential scope, `temporal.tls`, and its own primed reloader, or shares the process's `tls` pair and reloader, as the project records; see [worker.md](../../orchestrating-temporal-workflows/references/worker.md#temporal-transport-security).
