---
type: regex
target: { source: file, path: deployment.md }
pattern: '^(?![\s\S]*step-ca:latest)(?=[\s\S]*(?:\b(?:CA|step-ca)\b[^\n]{0,80}\b(?:per|each|every)[ -]environment|\b(?:per|each|every)[ -]environment[^\n]{0,80}\b(?:CA|step-ca)\b|separate (?:CA|step-ca)s?[^\n]{0,40}(?:staging|production)))(?=[\s\S]*(?:root[^\n]{0,80}offline|offline[^\n]{0,80}root))(?=[\s\S]*intermediate[^\n]{0,120}password|[\s\S]*password[^\n]{0,120}intermediate)(?=[\s\S]*(?:auto-?deploy[^\n]{0,40}(?:\boff\b|disabled|false)|(?:disable|turn off|switch off)[^\n]{0,20}auto-?deploy))(?=[\s\S]*(?:ca-db|ca-data|step-ca-data|/home/step|badger)[^\n]{0,80}(?:volume|persist)|[\s\S]*(?:volume|persist)[^\n]{0,80}(?:ca-db|ca-data|/home/step|badger))(?=[\s\S]*smallstep/step-ca(?:@sha256:|:v?\d+\.\d+))'
flags: i
---
