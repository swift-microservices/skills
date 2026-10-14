---
type: regex
target: { source: file, path: .github/workflows/checks.yml }
pattern: '^(?=[\s\S]*enable_linux_static_sdk_build:\s*true)(?=[\s\S]*linux_static_sdk_versions:\s*["'']?\[\s*"6\.3"\s*\])(?=[\s\S]*linux_static_sdk_build_command:[\s\S]{0,200}--disable-automatic-resolution[\s\S]{0,200}--product)'
---
