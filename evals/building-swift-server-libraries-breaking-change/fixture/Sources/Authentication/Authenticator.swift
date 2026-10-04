// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

/// Proves a credential and returns the identity it belongs to.
///
/// An authenticator returns `nil` to decline a credential it does not recognize, so another
/// authenticator may try it, and throws when the credential is recognized but invalid.
public protocol Authenticator<Credential, Identity>: Sendable {
    /// The credential a caller presents, such as a bearer token.
    associatedtype Credential: Sendable

    /// The identity a valid credential proves.
    associatedtype Identity: Sendable

    /// Returns the identity the credential proves, `nil` to decline it, or throws when it is invalid.
    func authenticate(_ credential: Credential) async throws -> Identity?
}
