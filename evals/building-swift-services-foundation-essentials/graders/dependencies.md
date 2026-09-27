---
type: llm
---

PASS if the generated manifest raises its dependency floors to the supplied compatible release snapshot (Hummingbird 2.27.0, hummingbird-auth 2.5.0, swift-openapi-runtime 1.12.1, and NIO 2.103.0), explicitly selects Hummingbird's ConfigurationSupport without FullFoundation or defaults, opts OpenAPI runtime out of defaults, and replaces both the target product and source import of NIOFoundationCompat with NIOFoundationEssentialsCompat while retaining the ByteBuffer JSON functionality. Accept equivalent version-requirement syntax, manifest formatting, and modern API implementation choices.
FAIL if Hummingbird uses traits: [] and loses the required configuration feature, FullFoundation/default traits remain enabled on either dependency, only NIO's version changes while its old compatibility product remains, dependencies are downgraded, a needed feature is removed, or the model claims it checked current upstream releases over the network despite the offline fixture. A manifest edit alone must not be reported as proof that the binary passed a linking check.
