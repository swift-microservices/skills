---
type: regex
target: { source: file, path: acme-documents/Sources/Documents/Serve/Serve.swift }
pattern: '^(?=[\s\S]*?ConfigReader\(\s*providers:\s*\[\s*EnvironmentVariablesProvider\(\)[^\]]*?InMemoryProvider)(?=[\s\S]*?scoped\(to:\s*"postgres"\))(?=[\s\S]*?scoped\(to:\s*"tls"\))(?=[\s\S]*?scoped\(to:\s*"grpc(?:\.server)?"\))(?![\s\S]*?"(?:/run/|/etc/|/var/|0\.0\.0\.0|127\.0\.0\.1|localhost))(?![\s\S]*?\bguard\b[^\n]*(?:[cC]onfig|\bport\b|\bhost\b|[pP]ath\b))(?![\s\S]*?\(config:(?:[^()\n]|\([^()\n]*\))*,\s*\w*(?:[Pp]ath|[Dd]irectory)\s*:)'
---
