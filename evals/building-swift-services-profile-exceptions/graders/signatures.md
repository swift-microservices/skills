---
type: regex
target: { source: file, path: boundaries.md }
pattern: '^(?=(?:[\s\S]*?callAsFunction\(\s*subject:\s*UserIdentity\s*,?\s*\)){2})(?=(?:[\s\S]*?callAsFunction\(\s*subject:\s*UserIdentity\s*,\s*input:){2})(?![\s\S]*?struct\s+\w*Input\b[^{]*\{\s*\})(?![\s\S]*?callAsFunction\([^)]*\b(?:user|account)I[dD]\s*:)'
---
