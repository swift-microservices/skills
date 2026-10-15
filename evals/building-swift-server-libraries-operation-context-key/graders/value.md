---
type: regex
target: { source: file, path: swift-request-id/Sources/RequestID/RequestID.swift }
pattern: '^(?![\s\S]*@TaskLocal)[\s\S]*public\s+struct\s+RequestID\s*:[^{]*\bSendable\b'
---
