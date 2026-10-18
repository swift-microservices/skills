---
type: regex
target: { source: file, path: .github/workflows/tests.yml }
pattern: '^(?=[\s\S]*workflow_call)(?=[\s\S]*services:[\s\S]*postgres)(?=[\s\S]*pg_isready\s+-h\s+(?:127\.0\.0\.1|localhost))(?=[\s\S]*swift\s+test\s+-c\s+release)(?![\s\S]*continue-on-error)'
---
