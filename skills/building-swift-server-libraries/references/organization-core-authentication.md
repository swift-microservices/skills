# The organization core: authentication

Every source file of `<Project>Authentication`. The layout, the manifest, `<Project>Testing`, and the required tests are in [organization-core-code.md](organization-core-code.md).

## Contents

- [`<Project>Authentication`](#projectauthentication): `UserRole.swift`, `UserIdentity.swift`, `JWT+EdDSA.swift`, and `OperationContext+User.swift`


## `<Project>Authentication`

`UserRole.swift`: an open string, so a role this build does not know is never read as an administrator.

```swift
/// A user's role, as the token carries it.
public struct UserRole: RawRepresentable, Hashable, Codable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }
}

extension UserRole {
    public static let user: UserRole = "user"
    public static let admin: UserRole = "admin"
}
```

`UserIdentity.swift`: the JWT payload. `sub` decodes straight into a `UUID`, so a token whose subject is not a user id fails to decode.

```swift
public import JWTKit

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// A user as their access token names them: who, in what role, issued by whom, until when.
public struct UserIdentity: JWTPayload, Equatable, Sendable {
    public let userId: UUID
    public let role: UserRole
    public let iss: IssuerClaim
    public let iat: IssuedAtClaim
    public let exp: ExpirationClaim

    public init(userId: UUID, role: UserRole, issuer: String, issuedAt: Date, expiration: Date) {
        self.userId = userId
        self.role = role
        self.iss = IssuerClaim(value: issuer)
        self.iat = IssuedAtClaim(value: issuedAt)
        self.exp = ExpirationClaim(value: expiration)
    }

    public var issuer: String { iss.value }
    public var issuedAt: Date { iat.value }
    public var expiration: Date { exp.value }

    public func verify(using algorithm: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }

    private enum CodingKeys: String, CodingKey {
        case userId = "sub"
        case role
        case iss
        case iat
        case exp
    }
}
```

Add an audience claim and check it in `verify(using:)` when the deployment uses one; nothing else rides in the token.

`JWT+EdDSA.swift`: the conveniences take key values; loading key files stays in each executable.

```swift
public import AuthenticationJWT
public import JWTKit

extension JWTIssuer where Payload == UserIdentity {
    /// The issuer of user tokens, over the EdDSA private key only the authenticating service holds.
    public init(privateKey: EdDSA.PrivateKey) async {
        let keys = JWTKeyCollection()
        await keys.add(eddsa: privateKey)
        self.init(keys: keys)
    }
}

extension JWTAuthenticator where Payload == UserIdentity {
    /// The authenticator of user tokens, over the EdDSA public key every service holds.
    public init(publicKey: EdDSA.PublicKey) async {
        let keys = JWTKeyCollection()
        await keys.add(eddsa: publicKey)
        self.init(keys: keys)
    }
}
```

`OperationContext+User.swift`: the named accessor over swift-authentication's generic key, and the logging metadata provider an executable passes to `LoggingSystem.bootstrap`.

```swift
public import Authentication
public import Logging
public import OperationContext

extension OperationContext {
    /// The verified user behind the current request, bound by the bearer interceptor or middleware.
    ///
    /// `nil` is not a failure: the bindings identify a user without requiring one.
    public var user: Principal<UserIdentity, String>? {
        get { self[PrincipalKey<UserIdentity, String>.self] }
        set { self[PrincipalKey<UserIdentity, String>.self] = newValue }
    }
}

extension Logger.MetadataProvider {
    /// Puts the bound user's id on every log line, as `user_id`; adds nothing when no user is
    /// bound, and never the credential.
    public static let user = Logger.MetadataProvider {
        guard let user = OperationContext.current.user else {
            return [:]
        }

        return ["user_id": "\(user.identity.userId)"]
    }
}
```
