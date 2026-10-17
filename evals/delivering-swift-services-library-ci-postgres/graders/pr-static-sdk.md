---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: '^(?=[\s\S]*swift_package_test\.yml@[0-9a-f]{40})(?=[\s\S]*enable_linux_checks:\s*false)(?=[\s\S]*enable_linux_static_sdk_build:\s*true)'
---
