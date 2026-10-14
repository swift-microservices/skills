---
type: regex
target: { source: file, path: verification.md }
pattern: '^(?![\s\S]*(?:\b(?:I|we)\s+(?:ran|have run|verified|tested|performed|executed|confirmed)\b|\ball (?:checks|tests) (?:passed|succeeded)\b))(?=[\s\S]*(?:certificate-verify-peer|openssl\s+s_client|grpcurl|curl[^\n]*--cert))(?=[\s\S]*accounts:\d+)(?=[\s\S]*billing:\d+)(?=[\s\S]*(?:anonymous|no client cert|without a (?:client )?cert|missing (?:client )?cert))(?=[\s\S]*(?:untrusted|rogue|foreign CA|throwaway CA|another CA|self-signed))(?=[\s\S]*expired)(?=[\s\S]*(?:wrong (?:server )?(?:host)?name|hostname mismatch|name mismatch|mismatched (?:host)?name))'
flags: i
---
