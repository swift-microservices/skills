---
type: regex
target: { source: file, path: Makefile }
pattern: 'swift build[^\n]*--disable-automatic-resolution'
---
