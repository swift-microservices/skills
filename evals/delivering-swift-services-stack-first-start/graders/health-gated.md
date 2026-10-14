---
type: regex
target: { source: file, path: stack/compose.yaml }
pattern: '^(?![\s\S]*postgres:[ \t]*\n[ \t]*condition:[ \t]*service_started)(?![\s\S]*depends_on:[ \t]*(?:\[[^\]\n]*postgres|\n(?:[ \t]*-[ \t]*[\w-]+[ \t]*\n)*[ \t]*-[ \t]*[\w-]*postgres))(?=(?:[\s\S]*?pg_isready){2})(?=[\s\S]*postgres:[ \t]*\n[ \t]*condition:[ \t]*service_healthy)(?=[\s\S]*step["'',\s]+ca["'',\s]+health)(?=[\s\S]*\bca:[ \t]*\n[ \t]*condition:[ \t]*service_healthy)(?=[\s\S]*restart:[ \t]*["'']no["''])(?![\s\S]*\n(?:  [\w-]*(?:enroll|init|migrate|permission|setup)[\w-]*:[ \t]*(?:\n(?: {4}[^\n]*)?)*?\n[ \t]{4}|x-[\w-]*(?:enroll|init|setup)[\w-]*:[^\n]*(?:\n(?: {2}[^\n]*)?)*?\n[ \t]{2})restart:[ \t]*["'']?(?:always|unless-stopped|on-failure))'
---
