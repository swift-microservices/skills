---
type: llm
focus: { source: file, path: .github/workflows/image.yml }
---

PASS if this reusable workflow runs on an ARM64 runner (`ubuntu-24.04-arm`), builds the Containerfile natively for `linux/arm64` with `docker/build-push-action` set to `load: true` and `push: false`, runs `.github/scripts/check-image.sh` on that local image (passing whether the image has a worker command), and only after that check, in steps conditional on a publish input, tags and pushes that same image as the immutable short-SHA tag and the branch tag. Every action is pinned to a commit SHA.
FAIL if it builds under emulation or for another architecture, pushes from the build step, rebuilds before publishing, publishes before the check, or tags only `latest`.
