---
type: regex
target: { source: file, path: design.md }
flags: i
pattern: '\bldd\b|readelf|objdump|libFoundation\w*\.so|inspect\w*[^\n]{0,80}(?:linux )?(?:executable|binary|binaries)\b|(?:executable|binary)[^\n]{0,40}(?:linkage|inspection)'
---
