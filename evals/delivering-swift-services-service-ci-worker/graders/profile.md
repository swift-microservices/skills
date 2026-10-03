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

Run `python3 evals/delivering-swift-services-service-ci/checks/verify.py <workspace> --worker`
from the original plugin (requires PyYAML). Check runtime-helper behavior independently for
missing libraries and failing commands. Local checks are not live GitHub/image execution.

This repository explicitly uses 400-column formatting and varying Xcode author headers; preserve
that exception instead of imposing the library defaults. Validate both serve and worker commands,
and deploy both process applications from the same image. Do not claim Temporal runtime coverage:
this fixture exercises a worker command profile, not a real Temporal workflow.
