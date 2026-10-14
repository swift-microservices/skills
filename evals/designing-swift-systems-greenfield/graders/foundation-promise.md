---
type: regex
target: { source: file, path: design.md }
flags: i
match: not_contains
pattern: '(?:application|binary|binaries|service|executable|image|system)[^\n.]{0,60}\b(?:is|stays|remains|will be|are)\s+(?:foundation-free|free of (?:full )?foundation|essentials-only)'
---
