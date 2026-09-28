---
max_turns: 35
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
tags: [building, spiffe]
---

Design and sketch the identity lifecycle for a Swift ledger service under ./acme-ledger. Its external identity provider delivers complete certificate-chain/private-key/trust-bundle generations asynchronously. The provider implementation is supplied by our platform team. Use the published swift-microservices packages; define any application-owned boundary explicitly rather than inventing SDK APIs.

Ledger's identity is spiffe://prod.acme.example/ledger and its upstream is spiffe://prod.acme.example/billing. It serves protected internal RPCs and also calls billing. Show composition, processing of provider updates, readiness, and application shutdown responsibilities in code sketches, plus focused test scenarios. Do not implement a certificate issuer or modify a real deployment.

Explain behavior for these events: a replacement arrives with a mismatched key; the provider goes offline until current credentials expire; two generations arrive in quick succession; a renewal changes the workload ID; root A overlaps with B and is later removed; and an emergency revocation occurs while a long-lived RPC stream and an outgoing connection are active. The service must remain secure throughout.
