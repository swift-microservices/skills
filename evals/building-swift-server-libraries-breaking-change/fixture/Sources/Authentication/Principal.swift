// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

public import ServiceContextModule

/// A proven identity and the credential that proved it.
public struct Principal<Identity: Sendable, Credential: Sendable>: Sendable {
    /// The identity the credential proved.
    public let identity: Identity

    /// The credential, retained so it can be forwarded unchanged.
    public let credential: Credential

    /// Creates a principal from a proven identity and its credential.
    public init(identity: Identity, credential: Credential) {
        self.identity = identity
        self.credential = credential
    }
}

/// The `ServiceContext` key a transport binds a principal under.
public enum PrincipalKey<Identity: Sendable, Credential: Sendable>: ServiceContextKey {
    public typealias Value = Principal<Identity, Credential>

    public static var nameOverride: String? { "principal" }
}
