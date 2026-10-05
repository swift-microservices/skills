---
type: llm
focus: { source: file, path: .github/workflows/checks.yml }
---

PASS if this is a `workflow_call` workflow taking the service product as an input, with: a soundness job on `swiftlang/github-workflows/.github/workflows/soundness.yml` pinned to a 40-character commit SHA, with `api_breakage_check_enabled: false`, `docs_check_enabled: false`, `license_header_check_enabled: false`, since the repository keeps its recorded Xcode author headers, and `format_check_container_image: swift:6.3-noble`; a workflow-lint job that installs actionlint verified by `sha256sum` and runs it; and a `swift_package_test.yml` job pinned to a commit SHA with `linux_swift_versions` `["6.3"]`, `linux_os_versions` `["noble"]`, `linux_host_archs` `["aarch64"]`, `linux_build_command` running `swift test --disable-automatic-resolution`, `swift_flags` with `-Xswiftc -warnings-as-errors`, `--explicit-target-dependency-import-check error`, and `-Xswiftc -require-explicit-sendable`, the static Linux SDK build enabled for 6.3 with a locked release `--product` build, and macOS, iOS, and Windows checks disabled.
FAIL if any action or reusable workflow is referenced by tag or branch instead of a commit SHA, the job attaches database or other service containers, a step uses `continue-on-error`, or the workflow is scheduled.
