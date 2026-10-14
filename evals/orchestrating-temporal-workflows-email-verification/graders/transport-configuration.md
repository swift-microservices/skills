---
type: regex
target: { source: file, path: acme-accounts/Sources/Accounts/Worker/Run.swift }
pattern: '^(?=[\s\S]*let\s+(\w+)\s*=\s*\w+\.scoped\(to:\s*"temporal"\))(?=[\s\S]*TemporalWorker\(\s*configuration:\s*(?:TemporalWorker\.Configuration|\.init)\(configReader:\s*\1\s*\))(?=[\s\S]*let\s+(\w+)\s*=\s*\w+\.scoped\(to:\s*"temporal\.tls"\))(?=[\s\S]*let\s+(\w+)\s*=\s*try\s+TimedCertificateReloader\.make\w*\([\s\S]*?TemporalWorker\([\s\S]*?transportSecurity:\s*(?:try\s+)?\.mTLS\(config:\s*\2\s*,\s*certificateReloader:\s*\3\s*\))(?=[\s\S]*ServiceGroup\([\s\S]*?services:\s*\[[^\]]*\b\3\b)(?![\s\S]*(?:\.plaintext|noHostnameVerification|verification:\s*\.none|(?:forKey|scoped\(to):\s*"jwt))'
---
