# Repository guidelines

## What this package is

- One product, `Authentication`: `Authenticator`, `Principal`, and `PrincipalKey`. It depends only
  on swift-service-context.
- `authenticate` returns an identity, returns `nil` to decline, or throws for an invalid credential.

## What does not belong here

- Concrete credentials, cryptography, claims, or roles.
- Transport configuration or reading headers and metadata.

## Swift

- Swift 6.3, strict concurrency, swift-testing, doc comments on every public declaration.

## Releases

- Every pull request carries exactly one label: `⚠️ semver/major`, `🆕 semver/minor`,
  `🔨 semver/patch`, or `semver/none`.
- Releases are created by the Auto Release workflow, run by hand on `main`; a major bump is refused
  there and cut by hand. The latest release is 0.2.0.
- Consumers pin by tag, never by branch or path.
