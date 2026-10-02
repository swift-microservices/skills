import Configuration
import GRPCNIOTransportHTTP2
import NIOCertificateReloading

extension HTTP2ClientTransport.Posix.TransportSecurity {
    static func mTLS(config: ConfigReader, certificateReloader: any CertificateReloader, defaultTrustRootsPath: String) throws -> Self {
        let trustRootsPath = config.string(forKey: "trustRootsPath", default: defaultTrustRootsPath)
        return try .mTLS(certificateReloader: certificateReloader) {
            $0.trustRoots = .certificates([.file(path: trustRootsPath, format: .pem)])
            $0.serverCertificateVerification = .noVerification
        }
    }
}
