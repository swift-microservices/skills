---
type: regex
target: { source: file, path: .github/workflows/builds.yml }
pattern: '^(?:(?=[\s\S]*swift\s+build(?![^\n]*--package-path)[^\n]*--disable-default-traits)(?=[\s\S]*swift\s+build[^\n]*--package-path[^\n]*--disable-default-traits|[\s\S]*swift\s+build[^\n]*--disable-default-traits[^\n]*--package-path)|(?=[\s\S]*(?:^|\n)[ \t-]*[\w-]+:[ \t]*["'']?--disable-default-traits)(?=[\s\S]*swift\s+build(?![^\n]*--package-path)[^\n]*\$\{\{\s*matrix\.)(?=[\s\S]*swift\s+build[^\n]*--package-path[^\n]*\$\{\{\s*matrix\.))'
---
