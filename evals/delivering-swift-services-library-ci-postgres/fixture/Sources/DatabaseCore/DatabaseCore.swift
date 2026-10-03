import PersistencePostgres
public import PostgresNIO
import Logging

public typealias Configuration = PostgresClient.Configuration

/// A real database-backed operation; failure must propagate to the caller.
public func databaseResponds(configuration: Configuration) async throws -> Bool {
    let logger = Logger(label: "database-core")
    return try await PostgresClient.withClient(configuration: configuration, logger: logger) { client in
        try await client.withConnection { connection in
            let rows = try await connection.query("SELECT 42", logger: logger)
            for try await value in rows.decode(Int.self) { return value == 42 }
            return false
        }
    }
}
