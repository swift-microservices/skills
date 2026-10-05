---
type: llm
focus: { source: file, path: .github/scripts/check-image.sh }
---

PASS if this script, given an image, the service product, and a worker flag, fails when the image runs as root, runs `ldd` on the product binary and fails when a library is `not found` but accepts a static binary ("not a dynamic executable" or "statically linked"), fails when `ldd` errors otherwise, runs the image with `--help` and `serve --help`, runs `worker run --help` only when its worker argument is true, and uses `set -euo pipefail`.
FAIL if a failing command can be ignored (`|| true`) or the worker command runs when the flag is false.
