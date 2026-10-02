import Configuration
import NIOCertificateReloading

extension TimedCertificateReloader.Configuration {
    init(config: ConfigReader) throws {
        self.init(
            refreshInterval: config.int(forKey: "refreshIntervalSeconds", as: Duration.self, default: .seconds(60)),
            certificateSource: .init(location: .file(path: try config.requiredString(forKey: "certificatePath")), format: .pem),
            privateKeySource: .init(location: .file(path: try config.requiredString(forKey: "privateKeyPath")), format: .pem)
        )
    }
}
