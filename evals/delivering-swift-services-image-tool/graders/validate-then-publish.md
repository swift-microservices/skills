---
type: llm
focus: { source: file, path: acme-catalog/.github/workflows/image.yml }
---

PASS if this workflow builds the image with swift-container-plugin from the committed `Package.resolved` (no re-resolution, e.g. `--disable-automatic-resolution`), validates that built image — for example running it with `--help` and `serve --help` — before publishing it, and then publishes that same image (the validated digest, re-tagged with a registry copy such as `crane copy`, `skopeo copy`, or `docker buildx imagetools create` if needed) as an immutable short-SHA tag and the moving branch tag. A container runtime or copier used only to run or re-tag the plugin's image is not a second image tool.
FAIL if it builds under emulation, rebuilds the image for publication, publishes an image it never validated, or tags only `latest`.
