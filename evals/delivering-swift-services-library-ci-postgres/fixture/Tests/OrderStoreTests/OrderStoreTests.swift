// Copyright (c) 2026 Example Maintainers
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

import Foundation
import OrderStore
import PostgresNIO
import Testing

@Suite struct OrderStoreTests {
    @Test func countsOrders() async throws {
        let environment = ProcessInfo.processInfo.environment
        let host = try #require(environment["POSTGRES_HOST"], "set POSTGRES_HOST to a PostgreSQL 18 database")
        let configuration = PostgresClient.Configuration(
            host: host,
            port: Int(environment["POSTGRES_PORT"] ?? "5432") ?? 5432,
            username: environment["POSTGRES_USER"] ?? "postgres",
            password: environment["POSTGRES_PASSWORD"],
            database: environment["POSTGRES_DB"],
            tls: .disable
        )
        let client = PostgresClient(configuration: configuration)
        try await withThrowingDiscardingTaskGroup { group in
            group.addTask { await client.run() }
            try await client.query("CREATE TABLE IF NOT EXISTS orders (id int)")
            #expect(try await OrderStore(client: client).count() >= 0)
            group.cancelAll()
        }
    }
}
