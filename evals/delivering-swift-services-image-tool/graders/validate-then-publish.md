---
type: regex
target: { source: file, path: acme-catalog/.github/workflows/image.yml }
pattern: '^(?![\s\S]*setup-qemu-action)(?=[\s\S]*build-container-image)(?=[\s\S]*--disable-automatic-resolution)(?=[\s\S]*build-container-image[\s\S]*?(?:check-image\.sh|serve\s+--help)[\s\S]*?(?:imagetools\s+create|crane\s+(?:copy|cp|tag)|skopeo\s+copy|regctl\s+image\s+copy))(?![\s\S]*(?:imagetools\s+create|crane\s+(?:copy|cp|tag)|skopeo\s+copy|regctl\s+image\s+copy)[\s\S]*build-container-image)(?=[\s\S]*(?:GITHUB_SHA::7|github\.sha|SHORT_SHA|short_sha|rev-parse\s+--short))(?=[\s\S]*(?:ref_name|github\.ref|BRANCH))'
---
