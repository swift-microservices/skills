---
type: regex
target: { source: file, path: acme-documents/Sources/DocumentsPostgres/Migrations/Document/CreateDocumentsRLSPolicy.swift }
pattern: '^(?=[\s\S]*ENABLE ROW LEVEL SECURITY)(?=[\s\S]*current_setting\(\s*''app\.caller_user_id''\s*,\s*true\s*\))[\s\S]*WITH CHECK'
flags: i
---
