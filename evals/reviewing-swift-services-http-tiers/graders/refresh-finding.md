---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists as a Blocking (or at least Major) finding, citing Sources/Acme/Serve/Serve.swift, that the refresh route is registered in the identifying tier behind `BearerAuthenticationMiddleware`, so a refresh request is refused with 401 before its handler runs, and recommends moving it to the first tier beside sign-in.
FAIL if the refresh-route placement is not reported, has no file reference, or is approved.
