---
type: llm
focus: { source: file, path: .github/scripts/check-image.sh }
---

PASS if this script, given an image, the service product, a worker flag, and optionally the binary's path in the image (defaulting to `/app/<product>`), fails when the image runs as root unless `ALLOW_ROOT_IMAGE=true` is set, runs `ldd` on the binary and fails when a library is `not found` while accepting a static binary ("not a dynamic executable" or "statically linked"), runs the image with `--help` and `serve --help`, and runs `worker run --help` only when the worker flag is true.
FAIL if a failing command can be ignored (`|| true`, no `set -e`), root is accepted without `ALLOW_ROOT_IMAGE=true`, or the worker command runs when the flag is false.
