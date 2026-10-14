---
type: llm
focus: { source: file, path: stack/FIRST-START.md }
---

PASS if the steps fill `.env` from `.env.example`, render the stack with `docker compose config` before `docker compose up -d`, and are presented as steps to perform rather than as completed.
FAIL if it claims anything was run, or starts the stack without rendering it first.
