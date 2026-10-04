---
type: llm
---

PASS if all of these hold:
- The pull request gets exactly one label, `🆕 semver/minor`, because a breaking change before 1.0.0 is a minor release (0.3.0).
- The release is cut by the Auto Release workflow; the 0.2.0 tag is not moved or re-created.
- Dependent packages or conformers must adopt the non-optional return and raise their floor to 0.3.0.

FAIL if the label it recommends is `⚠️ semver/major`, `🔨 semver/patch`, or `semver/none` (naming other labels only to rule them out is fine), if it proposes 1.0.0 unprompted, or claims to have built, committed, or released anything.
