---
type: llm
focus: { source: file, path: acme-catalog/.github/workflows/image.yml }
---

PASS if this workflow builds the release image natively for the deploy host's architecture with one named image tool, smoke-checks that built image (for example running its `--help` and `serve --help`), and only then publishes that same image as an immutable short-commit-SHA tag and the moving branch tag.
FAIL if it builds under emulation (QEMU or a `platforms` list naming another architecture), rebuilds the image for publication, publishes an image it never checked, or tags only `latest`.
