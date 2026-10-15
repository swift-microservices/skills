---
type: regex
target: { source: file, path: stack/compose.yaml }
pattern: 'command:[^\n]*worker[^\n]*run|command:\s*\n\s*-\s*[''"]?worker[''"]?\s*\n\s*-\s*[''"]?run'
---
