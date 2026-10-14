---
type: regex
target: { source: file, path: AGENTS.md }
pattern: '^(?![\s\S]*\b(?:is|are|stays|remains|builds?)\s+(?:fully\s+)?Foundation-free)(?=[\s\S]*(?:Foundation[\s\S]{0,800}postgres-?nio|postgres-?nio[\s\S]{0,800}Foundation))(?=[\s\S]*(?:postgres-?nio[^\n]{0,80}\d+\.\d+\.\d+|\d+\.\d+\.\d+[^\n]{0,80}postgres-?nio))(?=[\s\S]*Foundation[\s\S]{0,1500}(?:release builds?|static (?:linux )?sdk|postgresql tests?|real postgresql))'
flags: i
---
