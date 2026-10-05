---
type: llm
focus: { source: file, path: .github/workflows/pull_request.yml }
---

PASS if this pull-request workflow runs on `pull_request` types opened, reopened, and synchronize and has: a soundness job on `swiftlang/github-workflows/.github/workflows/soundness.yml@0.0.15` with `api_breakage_check_enabled: false`, `license_header_check_enabled: true`, `format_check_container_image: swift:6.3-noble`, and `docs_check_targets` naming `ExampleSDK`, with no other soundness check disabled; a job calling the repository's reusable `./.github/workflows/builds.yml` build-and-consumer matrix in place of `unit_tests.yml`; an `apple/swift-nio/.github/workflows/release_builds.yml@main` job with `minimum_swift_version: "6.3"` and `linux_6_2_enabled: false`; an `apple/swift-nio/.github/workflows/static_sdk.yml@main` job with no `with:` inputs and no `needs:`; and no Foundation linking job, because the generated code imports full Foundation in both trait configurations (the exception recorded in AGENTS.md).
FAIL if it adds a schedule, a macOS job, an API-breakage or API-diff job, `continue-on-error` or `|| true`, `--disable-automatic-resolution`, extra static SDK architectures or versions, or keeps `unit_tests.yml` or any `swift test` for a package with no runtime tests.
