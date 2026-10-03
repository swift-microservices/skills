import DatabaseCore
import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Test("PostgreSQL executes the provider query", .timeLimit(.minutes(1)))
func providerQuery() async throws {
    let environment = ProcessInfo.processInfo.environment
    let host = try #require(environment["POSTGRES_HOST"])
    let configuration = Configuration(
        host: host,
        port: Int(environment["POSTGRES_PORT"] ?? "5432") ?? 5432,
        username: environment["POSTGRES_USER"] ?? "postgres",
        password: environment["POSTGRES_PASSWORD"],
        database: environment["POSTGRES_DB"] ?? "postgres",
        tls: .disable
    )
    #expect(try await databaseResponds(configuration: configuration))
}
