---
type: llm
---

PASS only if one shared SPIFFETransportSecurity is initialized with valid coherent material and used by both the server/interceptor and clients. Provider generations are processed serially through `update(certificateChain:privateKey:bundle:)`; mismatched keys and identity-changing updates are rejected without overwriting the valid snapshot. Failed renewal preserves only still-valid material. The provider owns attestation/fetch/retry and the update task belongs to a structured application lifecycle with cancellation/shutdown behavior. Separate file-watch callbacks cannot publish partial generations.

FAIL if the answer replaces shared state before validation, uses independent unowned Tasks per update, silently accepts a changed local identity, or asserts that SPIFFETransportSecurity itself contacts SPIRE. Application-owned protocols are allowed when identified as such; demand neither a real provider client nor a fake runnable SDK integration.
