---
type: regex
target: { source: file, path: .github/workflows/image.yml }
pattern: '^(?=[\s\S]*runs-on:\s*["'']?ubuntu-[\w.]*-arm)(?=[\s\S]*docker/build-push-action@[0-9a-f]{40})(?=[\s\S]*platforms:\s*linux/arm64)(?=[\s\S]*load:\s*true)(?=[\s\S]*push:\s*false)'
---
