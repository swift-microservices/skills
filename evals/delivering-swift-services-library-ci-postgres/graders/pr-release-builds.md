---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: 'release_builds\.yml@main[\s\S]*?minimum_swift_version:\s*["'']?6\.3[\s\S]*?linux_6_2_enabled:\s*false|release_builds\.yml@main[\s\S]*?linux_6_2_enabled:\s*false[\s\S]*?minimum_swift_version:\s*["'']?6\.3'
---
