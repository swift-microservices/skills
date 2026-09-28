---
type: llm
focus: { source: file, path: acme-api/Package.swift }
---

PASS if the manifest declares exactly two source targets, API and the Acme executable, plus an APITests test target; no Core or Postgres target and no database driver or swift-persistence dependency; the API target runs the OpenAPIGenerator plugin.
FAIL if a Core, Postgres, or repository target exists, a database dependency is declared, the APITests test target is missing, or the generator plugin is absent.
