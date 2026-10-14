---
type: llm
focus: { source: file, path: acme-sdk/Sources/AcmeSDK/AcmeAuthenticationClient.swift }
---

PASS if all of these hold:
- Sign-in throws `AuthenticationClientError` with `.invalidCredentials` only for a 401 response, and its generated client carries no `AuthenticationMiddleware`.
- For both sign-in and refresh, any other problem status is thrown as the problem (or another error that is not an `AuthenticationClientError`).
- Transport and decoding errors are not caught and converted.

FAIL if a catch-all wraps errors into `AuthenticationClientError`, a status other than 401 becomes `.invalidCredentials`, or a transport or decoding failure is converted into a credential rejection.
Grade only against these criteria; do not fail for issues they do not mention.
