---
type: llm
---

PASS if the design's runtime/dependency discussion prepares own code for modern FoundationEssentials APIs, requires checking current compatible upstream releases and their trait defaults, and acknowledges that selected server/database libraries may still require full Foundation. The design should make compatible dependency updates the remaining migration step where own code is already ready, followed by resolved-graph/linking verification. It must distinguish a current upstream constraint from an architectural reason to keep writing legacy APIs and from a permanent inability to avoid full Foundation. No particular migration date, framework replacement, or unverified latest version is required.
FAIL if it promises every application using Hummingbird is automatically free of Foundation/ICU, treats static SDK support as proof of that claim, recommends legacy date decoding until the community migrates, assumes all libraries have the same FullFoundation trait/default, or predicts a migration deadline without evidence.
