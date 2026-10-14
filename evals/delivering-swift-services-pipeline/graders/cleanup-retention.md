---
type: llm
focus: { source: file, path: acme-catalog/.github/workflows/cleanup-images.yml }
---

PASS if this workflow runs on a schedule (for example weekly cron), deletes old versions of the catalog container package while keeping a recent window of versions (for example the newest 30), and grants `packages: write` (or the deletion permission) only to the cleanup job.
FAIL if it deletes every version, keeps no window, runs on every push, or deletes images by a rule that can remove the current branch tags.
