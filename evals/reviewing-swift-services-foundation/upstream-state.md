# Verified state for the offline review

This is scenario evidence, not a claim that these versions remain latest forever.

- The resolved PostgresNIO version is 1.33.1. It requires NIOFoundationCompat and links full Foundation and ICU; no trait removes that requirement. The application must keep PostgresNIO.
- The resolved OpenAPI runtime version is 1.12.1. Its FullFoundation trait is enabled by default.
- The resolved AcmeAPIClient is 1.0.0, the newest compatible release; its manifest is in Upstream/AcmeAPIClient. The application must keep this client.
- The service's date wire contract is ISO 8601 with optional fractional seconds and numeric offsets, with no localized display formatting. Date.ISO8601FormatStyle and JSONDecoder are available in FoundationEssentials on its supported Swift 6.3 Linux runtime.
- The package also supports Apple SDKs, which do not provide FoundationEssentials.
