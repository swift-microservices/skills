#!/usr/bin/env python3
"""Check a package's migrations against the role and row-level security rules.

Usage: python3 check-rls.py [PACKAGE_DIR]

Reads every Swift file under PACKAGE_DIR/Sources (default: the current directory) and checks
the rules in references/migrations-and-rls.md:

- every policy's table enables row-level security;
- a tenant policy (one reading `app.caller_user_id`) names no role, guards the setting with
  `NULLIF(current_setting('app.caller_user_id', true), '')`, and has `USING` and `WITH CHECK`
  for the commands it covers;
- a table with a tenant policy also has a policy `TO` a role with `USING (true)`;
- no role is created with `BYPASSRLS` or `SUPERUSER`;
- in the executable's `Database/Migrations.swift`, one `add` per migration with no loop, each
  table before its policies, and `CreateInternalRole` or `CreateWorkerRole` before a policy
  that takes that role.

Prints `file:line: message` per problem and exits 1 if there is any; exits 0 otherwise. It reads
SQL from string literals and does not run it, so it complements, not replaces, probing the
policies as each role against a real database. Needs only Python 3.
"""
import argparse
import re
import sys
from pathlib import Path


def strip_comments(source):
    """Blank out comments, keeping string literals and line numbers intact."""
    out, i, n = [], 0, len(source)
    while i < n:
        if source.startswith('//', i):
            end = source.find('\n', i)
            end = n if end == -1 else end
            out.append(' ' * (end - i))
            i = end
        elif source.startswith('/*', i):
            end = source.find('*/', i + 2)
            end = n if end == -1 else end + 2
            out.append(re.sub(r'[^\n]', ' ', source[i:end]))
            i = end
        elif source.startswith('"""', i):
            end = source.find('"""', i + 3)
            end = n if end == -1 else end + 3
            out.append(source[i:end])
            i = end
        elif source[i] == '"':
            j = i + 1
            while j < n and source[j] not in '"\n':
                j += 2 if source[j] == '\\' else 1
            out.append(source[i:j + 1])
            i = j + 1
        else:
            out.append(source[i])
            i += 1
    return ''.join(out)


def string_literals(text):
    """Yield (offset, content) for each string literal, unescaping quotes."""
    i, n = 0, len(text)
    while i < n:
        if text.startswith('"""', i):
            end = text.find('"""', i + 3)
            end = n if end == -1 else end
            yield i, text[i + 3:end]
            i = end + 3
        elif text[i] == '"':
            j, chunk = i + 1, []
            while j < n and text[j] not in '"\n':
                if text[j] == '\\' and j + 1 < n:
                    chunk.append(text[j + 1] if text[j + 1] == '"' else text[j:j + 2])
                    j += 2
                else:
                    chunk.append(text[j])
                    j += 1
            yield i, ''.join(chunk)
            i = j + 1
        else:
            i += 1


def block(text, open_brace):
    depth = 0
    for k in range(open_brace, len(text)):
        if text[k] == '{':
            depth += 1
        elif text[k] == '}':
            depth -= 1
            if depth == 0:
                return text[open_brace + 1:k]
    return text[open_brace + 1:]


def clause(sql, keyword):
    """Return the parenthesized expression after USING or WITH CHECK, or None."""
    match = re.search(r'\b' + keyword + r'\s*\(', sql, re.I)
    if not match:
        return None
    depth, start = 0, match.end() - 1
    for k in range(start, len(sql)):
        depth += {'(': 1, ')': -1}.get(sql[k], 0)
        if depth == 0:
            return sql[start + 1:k]
    return sql[start + 1:]


class Migration:
    def __init__(self, name, path, line):
        self.name, self.path, self.line = name, path, line
        self.tables, self.secured, self.policies, self.roles = set(), set(), [], []


def read_migrations(sources, root):
    migrations = {}
    for path in sorted(sources.rglob('*.swift')):
        text = strip_comments(path.read_text())
        for struct in re.finditer(r'\bstruct\s+(\w+)\s*:[^{]*\bDatabaseMigration\b[^{]*\{', text):
            body_start = struct.end() - 1
            body = block(text, body_start)
            apply = re.search(r'\bfunc\s+apply\s*\([^)]*\)[^{]*\{', body)
            if not apply:
                continue
            offset = body_start + 1 + apply.end() - 1
            apply_body = block(text, offset)
            migration = Migration(struct.group(1), path.relative_to(root), text.count('\n', 0, struct.start()) + 1)
            for at, sql in string_literals(apply_body):
                line = text.count('\n', 0, offset + at) + 1
                flat = ' '.join(sql.split())
                for table in re.findall(r'\bCREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"?(\w+)"?', flat, re.I):
                    migration.tables.add(table.lower())
                for table in re.findall(r'\bALTER\s+TABLE\s+"?(\w+)"?\s+(?:FORCE\s+|ENABLE\s+)ROW\s+LEVEL\s+SECURITY', flat, re.I):
                    migration.secured.add(table.lower())
                policy = re.search(r'\bCREATE\s+POLICY\s+"?(\w+)"?\s+ON\s+"?(\w+)"?(.*)', flat, re.I)
                if policy:
                    migration.policies.append((policy.group(1), policy.group(2).lower(), policy.group(3), line))
                if re.search(r'\bCREATE\s+ROLE\b', flat, re.I):
                    migration.roles.append((flat, line))
            migrations[migration.name] = migration
    return migrations


def check(package_dir):
    root = package_dir.resolve()
    sources = root / 'Sources'
    if not sources.is_dir():
        return [f'{sources}: not found'], []
    migrations = read_migrations(sources, root)
    problems, notes = [], []
    secured = {table for m in migrations.values() for table in m.secured}
    tenant_tables, open_tables = {}, set()

    for migration in migrations.values():
        for sql, line in migration.roles:
            for attribute in ('BYPASSRLS', 'SUPERUSER'):
                if re.search(r'\b' + attribute + r'\b', sql, re.I):
                    problems.append(f'{migration.path}:{line}: {migration.name} creates a role with {attribute}; no serving role bypasses the policies')
        for name, table, rest, line in migration.policies:
            where = f'{migration.path}:{line}: policy {name} on {table}'
            if table not in secured:
                problems.append(f'{where}: no migration enables row-level security on {table}, so the policy is never applied')
            to = re.search(r'\bTO\s+("?[^\s"]*"?|\\\(\w+\)|"\\\(\w+\)")', rest, re.I)
            command = re.search(r'\bFOR\s+(ALL|SELECT|INSERT|UPDATE|DELETE)\b', rest, re.I)
            command = command.group(1).upper() if command else 'ALL'
            using, check_ = clause(rest, 'USING'), clause(rest, r'WITH\s+CHECK')
            if 'app.caller_user_id' in rest:
                tenant_tables.setdefault(table, where)
                if to:
                    problems.append(f'{where}: a tenant policy names no role; drop the TO clause')
                if command in ('ALL', 'SELECT', 'UPDATE', 'DELETE') and using is None:
                    problems.append(f'{where}: tenant policy for {command} has no USING clause')
                if command in ('ALL', 'INSERT', 'UPDATE') and check_ is None:
                    problems.append(f'{where}: tenant policy for {command} has no WITH CHECK clause, so a caller could write another tenant\'s rows')
                for setting in re.finditer(r"current_setting\s*\(\s*'app\.caller_user_id'\s*(,\s*true\s*)?\)", rest, re.I):
                    if not setting.group(1):
                        problems.append(f"{where}: read the setting as current_setting('app.caller_user_id', true), which yields NULL rather than an error when unset")
                    before = rest[:setting.start()]
                    if not re.search(r'NULLIF\s*\(\s*$', before, re.I):
                        problems.append(f"{where}: wrap the setting in NULLIF(..., ''), since a setting read after its transaction is '' and ''::uuid is an error")
            elif to and using is not None and using.strip().lower() == 'true':
                open_tables.add(table)

    for table, where in tenant_tables.items():
        if table not in open_tables:
            problems.append(f'{where}: no policy TO the internal role with USING (true), so administrators and internal RPCs see no rows')

    lists = [p for p in sources.rglob('Migrations.swift') if p.parent.name == 'Database']
    if not lists:
        notes.append('no Sources/<Executable>/Database/Migrations.swift; the migration order was not checked')
    for path in lists:
        text = strip_comments(path.read_text())
        rel = path.relative_to(root)
        for loop in re.finditer(r'\bfor\s+\w+\s+in\b[^{]*\{[^}]*\badd\s*\(', text):
            problems.append(f'{rel}:{text.count(chr(10), 0, loop.start()) + 1}: one add per migration, never a loop over a list')
        order = [(m.group(1), m.group(2), text.count('\n', 0, m.start()) + 1)
                 for m in re.finditer(r'\badd\s*\(\s*(\w+)\s*\(([^()]*(?:\([^()]*\)[^()]*)*)\)', text)]
        if not order:
            notes.append(f'{rel}: no add(...) calls found; the migration order was not checked')
            continue
        position = {name: index for index, (name, _, _) in enumerate(order)}
        for index, (name, arguments, line) in enumerate(order):
            migration = migrations.get(name)
            if migration:
                for _, table, _, _ in migration.policies:
                    creators = [m.name for m in migrations.values() if table in m.tables]
                    for creator in creators:
                        if creator in position and position[creator] > index:
                            problems.append(f'{rel}:{line}: {name} is added before {creator}, which creates {table}')
            for label, role in (('internalRole', 'CreateInternalRole'), ('workerRole', 'CreateWorkerRole')):
                if re.search(r'\b' + label + r'\s*:', arguments) and position.get(role, len(order)) > index:
                    problems.append(f'{rel}:{line}: {name} takes the {label} but {role} is not added before it')
    return problems, notes


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('package_dir', nargs='?', default='.', type=Path)
    args = parser.parse_args()
    problems, notes = check(args.package_dir)
    problems = list(dict.fromkeys(problems))
    for note in notes:
        print(f'note: {note}')
    for problem in problems:
        print(problem)
    if problems:
        return 1
    print('OK: migrations follow the role and row-level security rules')
    return 0


if __name__ == '__main__':
    sys.exit(main())
