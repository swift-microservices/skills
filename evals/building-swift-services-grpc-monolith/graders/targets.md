---
type: regex
target: { source: file, path: acme-backend/Package.swift }
pattern: 'UsersCore[\s\S]*UsersPostgres[\s\S]*UsersGRPC[\s\S]*CatalogCore[\s\S]*CatalogPostgres[\s\S]*CatalogGRPC|CatalogCore[\s\S]*CatalogPostgres[\s\S]*CatalogGRPC[\s\S]*UsersCore[\s\S]*UsersPostgres[\s\S]*UsersGRPC'
---
