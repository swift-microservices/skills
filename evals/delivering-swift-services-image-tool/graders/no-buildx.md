---
type: regex
target: { source: file, path: acme-catalog/.github/workflows/image.yml }
pattern: 'docker/build-push-action|docker/setup-buildx-action'
match: not_contains
---
