---
type: llm
focus: files
---

PASS if the created paths include `pull_request.yml`, `develop.yml`, `main.yml`, `checks.yml`, `image.yml`, and `cleanup-images.yml` under `acme-catalog/.github/workflows/`, and an image build definition under `acme-catalog/` (a Containerfile, or a Makefile or workflow invoking the static Linux SDK or swift-container-plugin).
FAIL if any of those workflow files is missing or nothing defines how the image is built.
