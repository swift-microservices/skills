---
type: llm
---

PASS if the workflows build the published image with `swift package ... build-container-image` and the aarch64 musl Swift SDK on an ARM64 runner, from the committed Package.resolved, keep a static Linux SDK build among the checks, validate the final image (for example run it with `--help`) before publishing that same image, publish an immutable short-SHA tag and the moving branch tag, and deploy to staging only after publication; the summary names the deploy secrets.
FAIL if the result adds a Containerfile, Buildx, or another image tool in place of the recorded one, calls the recorded tool a deviation to fix, builds under emulation, publishes an image it never validated, or tags images only `latest`.
