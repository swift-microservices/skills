---
type: llm
focus: { source: file, path: deployment.md }
---

PASS if all of these hold:
- A long-running renewer renews each leaf before it expires (`step ca renew`), rather than only at startup.
- The renewer publishes each new file atomically into the application's directory.
- A rekey (`step ca rekey`) stages and validates the new pair before publishing it, and acknowledges that publishing a key and a certificate is two renames, not one atomic step, so publication is coordinated.

FAIL if renewal depends solely on a startup job, the application's reloader is expected to request certificates, or two file renames are claimed to be pair-atomic.
