// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

import Authentication
import Testing

struct TableAuthenticator: Authenticator {
    struct Refused: Error {}

    let identities: [String: String]
    var refused: Set<String> = []

    func authenticate(_ credential: String) async throws -> String? {
        if refused.contains(credential) {
            throw Refused()
        }
        return identities[credential]
    }
}

@Suite
struct AuthenticatorTests {
    @Test("A known credential returns its identity")
    func knownCredential() async throws {
        let authenticator = TableAuthenticator(identities: ["token": "alice"])
        #expect(try await authenticator.authenticate("token") == "alice")
    }

    @Test("An unknown credential is declined with nil")
    func unknownCredentialIsDeclined() async throws {
        let authenticator = TableAuthenticator(identities: [:])
        #expect(try await authenticator.authenticate("other") == nil)
    }

    @Test("A refused credential throws")
    func refusedCredentialThrows() async throws {
        let authenticator = TableAuthenticator(identities: [:], refused: ["bad"])
        await #expect(throws: TableAuthenticator.Refused.self) {
            try await authenticator.authenticate("bad")
        }
    }
}
