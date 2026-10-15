---
type: regex
target: { source: file, path: acme-sdk/Sources/AcmeSDK/openapi-generator-config.yaml }
pattern: '^(?![\s\S]*\bserver\b)(?=[\s\S]*\btypes\b)(?=[\s\S]*\bclient\b)[\s\S]*accessModifier:\s*[''"]?public\b'
---
