---
type: llm
---

PASS only if fulfillment authorizes the exact production entitlements-worker ID inside the use case, before database changes or other effects. The policy denies the authenticated production audit worker and the staging worker with the same path. Test sketches must cover the allowed worker and both denials, asserting that denied requests perform no writes; rejection of staging at the trust boundary may additionally be described. Authentication and authorization failures are distinguished as unauthenticated versus forbidden/permissionDenied.

FAIL if any authenticated member of the domain can fulfill purchases, policy compares only a path/suffix/display name, the allowlist lives only in the transport interceptor/handler, or denial tests merely assert that a principal exists. Allow any equivalent use-case-owned policy representation.
