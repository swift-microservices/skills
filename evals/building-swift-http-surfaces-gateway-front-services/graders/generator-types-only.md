---
type: regex
target: { source: file, path: acme-api/Sources/API/openapi-generator-config.yaml }
pattern: 'generate:\s*(?:\[\s*[''"]?types[''"]?\s*\]|\n[ \t]*-[ \t]*[''"]?types[''"]?[ \t]*(?:\n(?![ \t]*-)|$))'
---
