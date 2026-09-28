---
type: llm
focus: { source: file, path: foundation-status.md }
---

PASS if the application note attributes its current full-Foundation linkage to the supplied resolved Vapor and PostgresNIO versions, preserves those required dependencies, and explains that own code should use FoundationEssentials and modern ISO 8601/JSON APIs now. It must say to recheck compatible upstream releases, trait activation across the graph, and the actual executable's linkage when updating dependencies; it must not treat the dated upstream constraint as permanent. Compatible dependency updates should be able to remove the remaining linkage without a further legacy API migration in own code, while publishing an upstream release alone does not update the application's pins. Required runtime shared libraries must still be shipped today.
FAIL if it imposes a guaranteed-failing Essentials-only gate on the application, recommends disabling a previously passing check to hide a regression, enables FullFoundation or legacy date formatters merely because the process already links Foundation, invents a disabling trait for Vapor/PostgresNIO, rewrites the selected database/framework, promises a community migration deadline, or claims a static SDK build proves absence of statically linked Foundation code.
