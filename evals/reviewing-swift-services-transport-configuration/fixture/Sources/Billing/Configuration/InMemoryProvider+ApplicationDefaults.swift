import Configuration

extension InMemoryProvider {
    static var applicationDefaults: Self {
        .init(values: [
            "tls.certificatePath": "/run/tls/cert.pem",
            "tls.privateKeyPath": "/run/tls/key.pem",
            "tls.trustRootsPath": "/run/tls/ca.pem",
            "temporal.tls.certificatePath": "/run/temporal-tls/cert.pem",
            "temporal.tls.privateKeyPath": "/run/temporal-tls/key.pem",
            "temporal.tls.trustRootsPath": "/run/temporal-tls/ca.pem",
        ])
    }
}
