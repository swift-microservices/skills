// Copyright (c) 2026 Example Maintainers
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

public import PostgresNIO

/// Stores orders in PostgreSQL.
public struct OrderStore: Sendable {
    let client: PostgresClient

    /// Creates a store over a running client.
    public init(client: PostgresClient) {
        self.client = client
    }

    /// Returns how many orders exist.
    public func count() async throws -> Int {
        let rows = try await client.query("SELECT count(*) FROM orders")
        for try await count in rows.decode(Int.self) {
            return count
        }
        return 0
    }
}
