---
type: llm
focus: { source: file, path: .github/workflows/image.yml }
---

PASS if the workflow runs `.github/scripts/check-image.sh` on the locally loaded image, passing whether the image has a worker command, and only after that check, in steps conditional on a publish input, tags and pushes that same image as the immutable short-SHA tag and the branch tag.
FAIL if it pushes from the build step, rebuilds before publishing, publishes before the check, or tags only `latest`.
