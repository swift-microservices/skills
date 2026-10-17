---
type: regex
target: { source: file, path: .github/workflows/deploy.yml }
pattern: '^(?=[\s\S]*workflow_dispatch:[\s\S]*commit:)(?=[\s\S]*swift-microservices/ci/\.github/workflows/deploy\.yml@[0-9a-f]{40})(?=[\s\S]*environment:\s*production)(?=[\s\S]*prod-service-41[\s\S]{0,40}prod-worker-41)'
---
