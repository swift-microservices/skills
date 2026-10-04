# swift-authentication

The shape of a proven caller: an authenticator, a credential issuer, and the principal a transport binds.

```swift
.package(url: "https://github.com/swift-microservices/swift-authentication.git", from: "0.2.0"),
```

```swift
.product(name: "Authentication", package: "swift-authentication"),
```

## Authenticators

An authenticator returns the identity a credential proves. It returns `nil` to decline a
credential it does not recognize, so a transport can try the next authenticator, and throws when
a recognized credential is invalid.

```swift
struct AppTokenAuthenticator: Authenticator {
    func authenticate(_ token: String) async throws -> AppToken? {
        try await keys.verify(token)
    }
}
```

## Requirements

Swift 6.3, macOS 15 or Linux.

## License

MIT. See [LICENSE](LICENSE).
