---
type: regex
target: { source: file, path: .github/workflows/tests.yml }
pattern: '^(?=[\s\S]*workflow_call)(?=[\s\S]*swift:6\.3-noble)(?=[\s\S]*swift:6\.4-(resolute|noble))(?=[\s\S]*nightly-6\.4\.x)(?=[\s\S]*nightly-main)'
---
