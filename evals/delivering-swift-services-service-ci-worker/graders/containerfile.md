---
type: regex
target: { source: file, path: Containerfile }
pattern: '^(?=[\s\S]*FROM\s+swift:6\.3-noble)(?=[\s\S]*swift\s+package\s+--disable-automatic-resolution\s+resolve)(?=[\s\S]*swift\s+build[\s\S]*?--disable-automatic-resolution)(?=[\s\S]*-Xswiftc\s+-warnings-as-errors)(?=[\s\S]*--explicit-target-dependency-import-check\s+error)(?=[\s\S]*-Xswiftc\s+-require-explicit-sendable)(?=[\s\S]*\nUSER\s+\S)(?![\s\S]*\nUSER\s+(?:root|0)\b)'
---
