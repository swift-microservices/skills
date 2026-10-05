---
type: llm
focus: { source: file, path: .github/workflows/builds.yml }
---

PASS if this is a `workflow_call` workflow whose one job runs a matrix of four toolchain containers — `swift:6.3-noble`, Swift 6.4 (`swift:6.4-resolute` or `-noble`), a `nightly-6.4.x` snapshot, and `nightly-main` — with `-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable` on the two releases and the same without `-Xswiftc -warnings-as-errors` on the snapshots, and builds both the SDK and a downstream consumer (`swift build --package-path …`), each with default traits and with `--disable-default-traits`. A Swift 6.4-only `-Xswiftc -Wwarning -Xswiftc UnusedImportAccess` for a generated-import warning is acceptable.
FAIL if it runs `swift test`, adds `UnusedImportAccess` to Swift 6.3 or the snapshots, builds only one trait configuration, or tolerates a failing step.
