---
type: regex
target: { source: file, path: acme-catalog/.github/workflows/checks.yml }
pattern: 'enable_linux_static_sdk_build:\s*true|--swift-sdk\s+aarch64-swift-linux-musl'
---
