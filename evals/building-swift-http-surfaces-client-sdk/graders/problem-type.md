---
type: regex
target: { source: file, path: acme-sdk/Sources/AcmeSDK/Problem.swift }
pattern: 'public\s+struct\s+Problem\s*:(?=[^{]*\b(?:Codable|Decodable)\b)(?=[^{]*\bSendable\b)(?=[^{]*\bHashable\b)[^{]*\bError\b'
---
