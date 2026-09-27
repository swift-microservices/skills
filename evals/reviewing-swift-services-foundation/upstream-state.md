# Verified state for the offline review

This is scenario evidence, not a claim that these versions remain latest forever.

- The resolved PostgresNIO version is 1.33.1. It requires NIOFoundationCompat and still links full Foundation and ICU. Its required functionality has no trait that removes this requirement. The application must retain PostgresNIO.
- The resolved OpenAPI runtime version is 1.12.1. Its FullFoundation trait is default-enabled and disabled by the application's direct traits: [] declaration.
- The supplied AcmeAPIClient manifest excerpt is from the resolved 1.0.0 client. Its dependency edge enables OpenAPI runtime's default traits again. It is the newest compatible client in this scenario, and the service cannot remove it. There is no newer compatible client release in this snapshot. Changing only the application's existing direct traits: [] cannot override the other edge; report the additional upstream constraint and a possible upstream client fix, rather than claiming full Foundation has been disabled everywhere.
- The service's date wire contract is ISO 8601 with optional fractional seconds and numeric offsets. It needs no localized display formatting. Date.ISO8601FormatStyle and JSONDecoder are available in FoundationEssentials on its supported Swift 6.3 Linux runtime.
- NotesCore/Notes/Note.swift's conditional import is an intentional fallback for supported Apple SDKs. It does not use any legacy API.

Postgres and the client are real requirements in this scenario. Neither their presence nor linkage alone is a defect. The new Notes/JSON/NoteJSONCodec.swift file is local application code and must be reviewed independently.
