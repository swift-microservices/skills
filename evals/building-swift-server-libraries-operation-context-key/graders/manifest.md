---
type: regex
target: { source: file, path: swift-request-id/Package.swift }
pattern: '^// swift-tools-version: ?6\.3(?![\s\S]*(?:unsafeFlags|\.package\(\s*path:|defaultIsolation))'
---
