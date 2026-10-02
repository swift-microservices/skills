---
type: llm
---

PASS if the report recognizes at least two correct elements, such as initial reloader priming, reader-only reloader configuration, explicit CA trust with server-side client verification, native Temporal client configuration, or the existing reloader being managed once in ServiceGroup. It treats TLS private keys as valid client credentials and the reloader argument as a legitimate runtime dependency. It distinguishes the intentional offline omissions from actual findings and makes no build or handshake claims.
FAIL if it requires client-hostname verification on the server, treats .noHostnameVerification on the server as disabling client-chain validation, forbids the client's TLS private key or runtime reloader parameter, claims the existing reloader is never started, or reports intentionally omitted code as a defect.
