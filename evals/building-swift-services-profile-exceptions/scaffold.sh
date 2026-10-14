#!/bin/bash
set -euo pipefail
cat > AGENTS.md <<'MD'
# acme-authentication

The authentication service for acme: sign-in, sessions and refresh rotation, auth codes, passkeys (WebAuthn), and password changes. A microservice built the swift-microservices way, served over gRPC behind the acme-api gateway.

## Project profile

- Executable target `AuthenticationServer` and gRPC target `AuthenticationRPC`: the default names `Authentication` and `AuthenticationGRPC` collide with modules of the swift-authentication packages this service links.
- `AuthenticationCore` imports the WebAuthn library directly and keeps its standard types (`RegistrationCredential`, `PublicKeyCredentialCreationOptions`) and its concrete `WebAuthnManager` in Core. Wrapping them behind a protocol adds no substitution seam, so there is no WebAuthn port.
- Provider network clients (the email sender, the Valkey challenge store) stay behind Core ports in their own `Authentication<Technology>` targets.
- Users is another service; Authentication reaches it through the `UserDirectory` port in Core, satisfied by a gRPC client adapter.

## Decisions

- Postgres placement: a database per service on one instance.
- Tenant isolation: row-level security on `app.caller_user_id` for the passkey and refresh-token tables.
MD
