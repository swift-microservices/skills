---
type: llm
---

PASS if all of these hold:
- The pull request is labelled `🔨 semver/patch`, a compatible addition for a 0.x package.
- Services add the middleware after `BearerAuthenticationMiddleware` on the identifying tier.
- The reply says AGENTS.md was updated to mention the HTTP binding.

FAIL if the label it recommends is `⚠️ semver/major` or `🆕 semver/minor` (naming other labels only to rule them out is fine), if it places the middleware before the bearer middleware, or claims a build or release happened.
