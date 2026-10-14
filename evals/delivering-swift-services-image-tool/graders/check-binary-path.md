---
type: regex
target: { source: file, path: acme-catalog/.github/workflows/image.yml }
pattern: '^(?![\s\S]*/app/(?:catalog|\$))(?=[\s\S]*(?:check-image\.sh(?:[ \t]+"?[^\s"]+"?){3}[ \t]+"?/(?!app/)|ldd["'']?[ \t]+["'']?/(?:catalog|\$)|/(?:catalog|\$\{?\w+\}?|\$\{\{\s*inputs\.\w+\s*\}\})["'']?[ \t]+serve[ \t]+--help))'
---
