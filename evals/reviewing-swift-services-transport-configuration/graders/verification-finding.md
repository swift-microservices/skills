---
type: llm
focus: trace
---

Judge the review report (it may come back from a forked review agent as a tool result, then be relayed in the final reply).

PASS if the report lists as a finding, citing Sources/Billing/Configuration/HTTP2ClientTransport.Posix.TransportSecurity+ConfigReader.swift, that the client transport factory disables server certificate verification (`.noVerification`), and recommends full verification of the server's certificate and hostname.
FAIL if the finding is missing or has no file reference, or the report proposes disabling verification anywhere.
