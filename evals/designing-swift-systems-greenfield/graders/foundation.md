---
type: regex
target: { source: file, path: design.md }
flags: i
pattern: '(?:postgres-?nio|postgreskit|vapor|postgres driver)(?:(?!\.\s)[^\n]){0,80}?\b(?:links?|linking|pulls? in|requires?|brings? in|imports?|depends on)\b(?:(?!\.\s)[^\n]){0,40}?(?:full foundation|foundationinternationalization)|(?:full foundation|foundationinternationalization)(?:(?!\.\s)[^\n]){0,80}?(?:postgres-?nio|postgreskit|vapor|postgres driver)(?:(?!\.\s)[^\n]){0,30}?\b(?:links?|requires?|pulls? it in|brings? it in)\b'
---
