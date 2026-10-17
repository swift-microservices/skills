---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: '^(?=[\s\S]*swift-microservices/ci/\.github/workflows/build-image\.yml@[0-9a-f]{40})(?![\s\S]*publish:\s*true)'
---
