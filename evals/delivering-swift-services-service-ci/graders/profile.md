---
type: llm
---

PASS only if actual artifacts implement the service profile: PR checks without publication;
develop/main checks, native final-image validation before publishing that same image and ordered
deployment; one deployed toolchain/OS/architecture, tracked validated lockfile for every build,
released ARM64 musl SDK compatibility, source/workflow lint, reviewed SHA-pinned actions,
weekly Swift/Actions updates against develop and serialized deployment branches. No snapshots,
API-diff/SemVer gates, scheduled testing, unwanted platforms or new infrastructure fixtures.
Keep the existing behavior tests and actual license. Inspect the artifacts, not just prose.

Run `python3 evals/delivering-swift-services-service-ci/checks/verify.py <workspace>`
from the original plugin (requires PyYAML). Check runtime-helper behavior independently for
missing libraries and failing commands. Local checks are not live GitHub/image execution.

This service has no style exception: use the shared 150-column formatter and compact MIT headers.
Do not discard or ignore its application lockfile under the library rule.
