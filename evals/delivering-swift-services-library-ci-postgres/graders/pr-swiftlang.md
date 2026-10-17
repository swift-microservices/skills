---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: '^(?=[\s\S]*swiftlang/github-workflows/\.github/workflows/soundness\.yml@[0-9a-f]{40})(?![\s\S]*apple/swift-nio/\.github/workflows)'
---
