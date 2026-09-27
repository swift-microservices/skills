---
type: llm
---

PASS if the generated Workflow/Activity/payload code uses FoundationEssentials wherever Foundation values are needed (directly or through an SDK fallback) and uses modern date/JSON APIs when such conversion is required. A file needing no Foundation types should have no unnecessary Foundation import. Required PostgresNIO linkage is not a reason to use legacy local APIs, and a modern API is not permission to read the real clock or environment during Workflow replay. Existing stored payload representations must not be changed merely to adopt another date API.
FAIL if generated code introduces DateFormatter, ISO8601DateFormatter, NumberFormatter, or String(format:), assumes localized FormatStyle APIs avoid ICU automatically, changes payload wire formats without considering history compatibility, or uses nondeterministic wall-clock/locale formatting inside a Workflow.
