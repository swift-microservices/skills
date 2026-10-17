---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: '^(?=[\s\S]*swift_package_test\.yml@[0-9a-f]{40})(?=[\s\S]*linux_swift_versions:\s*["'']?\[\s*"6\.3"\s*\])(?=[\s\S]*linux_os_versions:\s*["'']?\[\s*"noble"\s*\])(?=[\s\S]*linux_host_archs:\s*["'']?\[\s*"aarch64"\s*\])(?=[\s\S]*swift\s+test[^\n]*--disable-automatic-resolution)(?=[\s\S]*-warnings-as-errors)(?=[\s\S]*--explicit-target-dependency-import-check\s+error)(?=[\s\S]*-require-explicit-sendable)'
---
