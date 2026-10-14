---
type: regex
target: { source: file, path: .github/workflows/pull_request.yml }
pattern: '^(?=[\s\S]*swiftlang/github-workflows/\.github/workflows/soundness\.yml@0\.0\.15)(?=[\s\S]*api_breakage_check_enabled:\s*false)(?=[\s\S]*license_header_check_enabled:\s*true)(?=[\s\S]*format_check_container_image:\s*["'']?swift:6\.3-noble)(?=[\s\S]*docs_check_targets:[^\n]*DatabaseCore)'
---
