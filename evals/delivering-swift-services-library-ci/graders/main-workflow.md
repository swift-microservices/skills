---
type: llm
focus: { source: file, path: .github/workflows/main.yml }
---

PASS if this workflow runs on `push` to `main` and has the same test job as the pull-request workflow (an `apple/swift-nio/.github/workflows/unit_tests.yml@main` job with `minimum_swift_version: "6.3"`, `linux_6_2_enabled: false`, the 6.3 and 6.4 argument overrides `-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable`, and the nightly-next and nightly-main overrides the same without `-Xswiftc -warnings-as-errors`), an `apple/swift-nio/.github/workflows/release_builds.yml@main` job with `minimum_swift_version: "6.3"` and `linux_6_2_enabled: false`, and two `vapor/ci/.github/workflows/check-foundation-linking.yml@main` jobs, one with `swift_image: swift:6.3-noble` and one with `swift:6.4-noble`.
FAIL if it runs the static SDK workflow, a soundness job, a schedule, or a macOS job.
