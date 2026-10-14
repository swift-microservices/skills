---
type: llm
focus: { source: file, path: .github/workflows/builds.yml }
---

PASS if the SDK and the consumer are each built with default traits and with `--disable-default-traits`, the two release toolchains use `-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable` and the two snapshots the same without `-Xswiftc -warnings-as-errors`. A Swift 6.4-only `-Xswiftc -Wwarning -Xswiftc UnusedImportAccess` for a generated-import warning is acceptable.
FAIL if `UnusedImportAccess` is added to Swift 6.3 or the snapshots, only one trait configuration is built, or warnings-as-errors is dropped from a release toolchain.
