---
type: regex
target: { source: file, path: acme-backend/Sources/UsersGRPC/Users/UserService.swift }
pattern: '^(?=[\s\S]*?func \w*[Pp]rofile\w*\([^{]*\{\s*let \w+ = try (?:self\.)?requireUser\(\))(?=[\s\S]*?func \w+\([^{]*\{\s*let \w+ = try (?:self\.)?requireAdministrator\(\))(?![\s\S]*?func \w*[Pp]rofile\w*\([^{]*\{\s*(?!\s|let \w+ = try (?:self\.)?requireUser\(\)))(?![\s\S]*?func sign(?:Up|In)\w*\([^{]*\{\s*(?:let \w+ = )?try (?:self\.)?require)(?![\s\S]*?func \w*[Pp]rofile\w*\((?:(?!\n\s*(?:package |public |private |internal )?func )[\s\S])*?(?:request\.(?:user)?[iI][dD]\b|requireAdministrator|\.role\b))'
---
