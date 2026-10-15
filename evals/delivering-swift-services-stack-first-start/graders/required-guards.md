---
type: regex
target: { source: file, path: stack/compose.yaml }
match: not_contains
pattern: '\$\{\w*(?:PASSWORD|SECRET)\w*:-'
---
