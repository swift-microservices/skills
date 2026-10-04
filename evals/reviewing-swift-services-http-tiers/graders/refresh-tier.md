---
type: llm
---

PASS if the review reports as a blocking (or at least major) finding, citing Sources/Acme/Serve/Serve.swift, that the refresh route is registered in the identifying tier behind `BearerAuthenticationMiddleware`, so a refresh token or an expired access token in the Authorization header is refused with 401 before the handler runs; and recommends moving it to the first tier beside sign-in.
FAIL if the refresh-route placement is not reported, is reported without a file reference, or the reviewer approves it.
