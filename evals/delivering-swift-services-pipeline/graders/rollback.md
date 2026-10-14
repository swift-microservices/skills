---
type: llm
---

PASS if the reply says rolling staging back means pinning the staging application to an older short-SHA image tag on the platform and deploying it by hand, outside the pipeline, and that only SHAs still inside the registry's retention window can be pulled.
FAIL if rollback requires reverting and rebuilding through the pipeline, re-tagging `latest`, or reverting the database schema.
