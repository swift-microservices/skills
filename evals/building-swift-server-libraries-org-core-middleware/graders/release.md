---
type: llm
---

PASS if all of these hold:
- The pull request is labelled `🔨 semver/patch`, a compatible addition for a 0.x package.
- Services add the middleware after `BearerAuthenticationMiddleware` in the identifying tier (the group that identifies a caller but still admits anonymous requests).

FAIL if the label it recommends is `⚠️ semver/major`, `🆕 semver/minor`, or `semver/none` (naming other labels only to rule them out is fine), if it places the middleware before the bearer middleware or only in the requiring tier, or claims a build or release happened.
Grade only against these criteria; do not fail for issues they do not mention.
