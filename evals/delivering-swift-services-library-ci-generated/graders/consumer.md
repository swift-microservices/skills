---
type: llm
focus: { source: file, path: .github/Fixtures/Consumer/Package.swift }
---

PASS if this consumer manifest depends on the SDK checkout by `.package(path:` and forwards its transport trait explicitly (for example a consumer trait that enables the SDK's `URLSessionTransport` with `.when(traits:` or `traits:` on the dependency), so the default and `--disable-default-traits` builds exercise different SDK configurations.
FAIL if the consumer depends on a released version instead of the checkout, or both builds necessarily resolve the same trait set.
