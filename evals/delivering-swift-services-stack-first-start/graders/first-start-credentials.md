---
type: regex
target: { source: file, path: stack/FIRST-START.md }
pattern: '^(?![\s\S]*(?:export\s+JWT|JWT_PRIVATE_KEY\s*=|JWT_[A-Z_]*KEY\s*=\s*["'']?\$\())(?=[\s\S]*root[^\n]*offline|[\s\S]*offline[^\n]*root)(?=[\s\S]*provisioner)(?=[\s\S]*(?:token[^\n]*(?:\d+[ -]*min|minute|short-lived|single-use|one-time|accepted once)|(?:\d+[ -]*min|minute|short-lived|single-use|one-time)[^\n]*token))(?=[\s\S]*?enroll[\s\S]*?renew[\s\S]*?docker\s+compose\s+up\s+-d[ \t]*(?:#[^\n]*)?(?:\n|$))(?=(?:(?!docker\s+compose\s+up\s+-d[ \t]*(?:#[^\n]*)?(?:\n|$))[\s\S])*?(?:enroll\.sh|--profile\s+enroll|step\s+ca\s+certificate|certificate-enroll))(?=[\s\S]*(?:generate-jwt-keys|genpkey)[^\n]*secrets/)(?=[\s\S]*(?:umask\s+0?077|chmod\s+0?700|generate-jwt-keys))'
---
