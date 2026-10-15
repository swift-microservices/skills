#!/usr/bin/env python3
"""Check a package manifest against the organization's Swift settings.

Usage: python3 check-swift-settings.py [PACKAGE_DIR] [--exempt TARGET ...]

Reads PACKAGE_DIR/Package.swift (default: the current directory) and checks the rules in
references/swift-settings.md: tools version 6.3, `swiftLanguageModes: [.v6]`, `.macOS(.v15)`,
one stored `[SwiftSetting]` array enabling exactly the four upcoming features, that array
passed to every `.target`, `.executableTarget`, and `.testTarget`, no `unsafeFlags`, and no
MainActor default isolation. Pass `--exempt` for a C target, which takes no Swift settings.

Prints one line per problem and exits 1 if there is any; exits 0 and prints OK otherwise.
It reads the manifest as text and does not evaluate it, so a manifest that builds its target
list in code is reported as unattached; check that one by hand. Needs only Python 3.
"""
import argparse
import re
import sys
from pathlib import Path

FEATURES = {
    'ExistentialAny',
    'MemberImportVisibility',
    'InternalImportsByDefault',
    'NonisolatedNonsendingByDefault',
}
TARGET_KINDS = ('target', 'executableTarget', 'testTarget')


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
            while j < n and source[j] != '"' and source[j] != '\n':
                j += 2 if source[j] == '\\' else 1
            out.append(source[i:j + 1])
            i = j + 1
        else:
            out.append(source[i])
            i += 1
    return ''.join(out)


def call_arguments(text, open_paren):
    """Return the text between a call's parentheses, given the index of its '('."""
    depth = 0
    for k in range(open_paren, len(text)):
        if text[k] in '([{':
            depth += 1
        elif text[k] in ')]}':
            depth -= 1
            if depth == 0:
                return text[open_paren + 1:k]
    return text[open_paren + 1:]


def target_declarations(text):
    """Yield the `.target(`-style calls at the top level of every `targets: [...]` array.

    A `.target(name:)` inside a `dependencies:` list names a dependency, not a declaration,
    so only calls directly in the array count.
    """
    kinds = re.compile(r'\.(' + '|'.join(TARGET_KINDS) + r')\s*\(')
    for array in re.finditer(r'\btargets:\s*\[', text):
        start = array.end()
        depth = 0
        k = start
        while k < len(text):
            char = text[k]
            if char == '"':
                k = text.find('"', k + 1) + 1 or len(text)
                continue
            if depth == 0:
                match = kinds.match(text, k)
                if match:
                    yield match
            if char in '([{':
                depth += 1
            elif char in ')]}':
                if depth == 0:
                    break
                depth -= 1
            k += 1


def line_of(text, index):
    return text.count('\n', 0, index) + 1


def check(package_dir, exempt):
    manifest = package_dir / 'Package.swift'
    if not manifest.is_file():
        return [f'{manifest}: not found']
    raw = manifest.read_text()
    text = strip_comments(raw)
    problems = []

    first = next((line for line in raw.splitlines() if line.strip()), '')
    if not re.fullmatch(r'//\s*swift-tools-version:\s*6\.3(?:\.0)?\s*', first):
        problems.append(f'line 1: tools version is {first.strip()!r}; use `// swift-tools-version: 6.3`')
    if not re.search(r'swiftLanguageModes:\s*\[\s*\.v6\s*\]', text):
        problems.append('Package: set `swiftLanguageModes: [.v6]`')
    if not re.search(r'platforms:\s*\[[^\]]*\.macOS\(\s*\.v15\s*\)', text):
        problems.append('Package: declare `platforms: [.macOS(.v15)]`')

    arrays = list(re.finditer(r'\blet\s+(\w+)\s*:\s*\[\s*SwiftSetting\s*\]\s*=\s*\[', text))
    if not arrays:
        problems.append('Package: no stored `let swiftSettings: [SwiftSetting] = [...]` array')
        name = None
    else:
        if len(arrays) > 1:
            names = ', '.join(m.group(1) for m in arrays)
            problems.append(f'Package: one shared settings array, found {len(arrays)} ({names})')
        array = arrays[0]
        name = array.group(1)
        body = call_arguments(text, array.end() - 1)
        enabled = set(re.findall(r'\.enableUpcomingFeature\(\s*"(\w+)"\s*\)', body))
        for feature in sorted(FEATURES - enabled):
            problems.append(f'line {line_of(text, array.start())}: `{name}` does not enable {feature}')
        for feature in sorted(enabled - FEATURES):
            problems.append(f'line {line_of(text, array.start())}: `{name}` also enables {feature}; only the four shared features belong here')

    for match in target_declarations(text):
        arguments = call_arguments(text, match.end() - 1)
        target = re.search(r'name:\s*"([^"]+)"', arguments)
        target = target.group(1) if target else '?'
        if target in exempt:
            continue
        setting = re.search(r'swiftSettings:\s*(\w+)', arguments)
        if not setting:
            problems.append(f'line {line_of(text, match.start())}: .{match.group(1)} "{target}" has no `swiftSettings:`')
        elif name and setting.group(1) != name:
            problems.append(f'line {line_of(text, match.start())}: .{match.group(1)} "{target}" passes `{setting.group(1)}`, not `{name}`')

    for pattern, message in (
        (r'\bunsafeFlags\s*\(', 'unsafe flags silence diagnostics; resolve them instead'),
        (r'defaultIsolation\s*\(\s*MainActor', 'server packages keep nonisolated default isolation'),
    ):
        for match in re.finditer(pattern, text):
            problems.append(f'line {line_of(text, match.start())}: {message}')
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('package_dir', nargs='?', default='.', type=Path)
    parser.add_argument('--exempt', nargs='*', default=[], metavar='TARGET', help='C targets that take no Swift settings')
    args = parser.parse_args()
    problems = check(args.package_dir, set(args.exempt))
    for problem in problems:
        print(f'Package.swift: {problem}')
    if problems:
        return 1
    print('OK: Package.swift follows the shared Swift settings')
    return 0


if __name__ == '__main__':
    sys.exit(main())
