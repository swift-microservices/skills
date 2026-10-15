---
type: regex
target: { source: file, path: stack/compose.yaml }
match: not_contains
pattern: '^\s*image:\s*[''"]?[\w./-]+(?::latest)?[''"]?\s*$|^\s+build:'
flags: m
---
