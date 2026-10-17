# OrderStore

A PostgreSQL store for orders, released with SemVer labels and Auto Release. MIT, owned by
Example Maintainers. Swift 6.3 is the supported floor.

- One library product, `OrderStore`, over PostgresNIO 1.33, which links full Foundation.
- The tests exercise real SQL against PostgreSQL 18, read the connection from `POSTGRES_HOST`,
  `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`, and fail when no
  database is configured.
- There is no `assert` or `#if DEBUG` code.
