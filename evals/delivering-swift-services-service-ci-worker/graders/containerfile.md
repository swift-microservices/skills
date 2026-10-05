---
type: llm
focus: { source: file, path: Containerfile }
---

PASS if the build stage is `FROM swift:6.3-noble`, resolves with `swift package --disable-automatic-resolution resolve`, builds the release product with `--disable-automatic-resolution` and `-Xswiftc -warnings-as-errors`, `--explicit-target-dependency-import-check error`, and `-Xswiftc -require-explicit-sendable`, and the final stage copies the staged directory into `/app` and runs as an unprivileged user.
FAIL if resolution or the build can change the lockfile, the image toolchain differs from CI's 6.3, or the final image runs as root.
