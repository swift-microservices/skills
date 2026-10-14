---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: '^(?=[\s\S]*apple/swift-nio/\.github/workflows/unit_tests\.yml@main)(?=[\s\S]*minimum_swift_version:\s*["'']?6\.3)(?=[\s\S]*linux_6_2_enabled:\s*false)(?=[\s\S]*linux_6_3_arguments_override:\s*["'']?-Xswiftc\s+-warnings-as-errors\s+--explicit-target-dependency-import-check\s+error\s+-Xswiftc\s+-require-explicit-sendable)(?=[\s\S]*linux_6_4_arguments_override:\s*["'']?-Xswiftc\s+-warnings-as-errors\s+--explicit-target-dependency-import-check\s+error\s+-Xswiftc\s+-require-explicit-sendable)(?=[\s\S]*linux_nightly_next_arguments_override:\s*["'']?--explicit-target-dependency-import-check\s+error\s+-Xswiftc\s+-require-explicit-sendable)(?=[\s\S]*linux_nightly_main_arguments_override:\s*["'']?--explicit-target-dependency-import-check\s+error\s+-Xswiftc\s+-require-explicit-sendable)'
---
