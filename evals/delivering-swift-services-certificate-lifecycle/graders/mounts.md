---
type: regex
target: { source: file, path: deployment.md }
pattern: '^(?![\s\S]*(?:TLS_PRIVATE_KEY|TLS_KEY|PRIVATE_KEY_PEM|KEY_PEM)\s*[=:]\s*["'']?-----BEGIN)(?=[\s\S]*gateway-tls)(?=[\s\S]*accounts-tls)(?=[\s\S]*billing-tls)(?=[\s\S]*billing-temporal[\w-]*tls)(?=[\s\S]*billing-worker[\w-]*tls)(?=[\s\S]*/run/tls)(?=[\s\S]*/run/temporal-tls)(?=[\s\S]*(?:/run/(?:temporal-)?tls:ro\b|read-only|read_only|\b2750\b|\b0?640\b|\b0?440\b))(?=[\s\S]*(?:only writer|sole writer|renewers? (?:is|are) the only|only the renewer))(?=[\s\S]*\$\{\{\s*environment\.)'
flags: i
---
