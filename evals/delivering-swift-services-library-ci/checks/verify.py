#!/usr/bin/env python3
"""Check generated CI artifacts, independent of grader prose. Requires PyYAML.

Run against a kept eval workspace or real library; exceptions are explicit CLI inputs.
Workflow/provider behavior still requires running on GitHub/a real database.
"""
import argparse
import os
import re
import json
import subprocess
from pathlib import Path

import yaml

# YAML 1.1 treats GitHub's `on` key as a boolean. Restrict booleans to true/false.
class WorkflowLoader(yaml.SafeLoader):
    pass

WorkflowLoader.yaml_implicit_resolvers = {
    key: [(tag, value) for tag, value in resolvers if tag != 'tag:yaml.org,2002:bool']
    for key, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
}
WorkflowLoader.add_implicit_resolver(
    'tag:yaml.org,2002:bool', re.compile(r'^(?:true|false|True|False|TRUE|FALSE)$'), list('tTfF')
)

NIO = 'apple/swift-nio/.github/workflows/'
FOUNDATION = 'vapor/ci/.github/workflows/check-foundation-linking.yml@main'
SOUNDNESS = 'swiftlang/github-workflows/.github/workflows/soundness.yml@0.0.15'
STABLE = '-Xswiftc -warnings-as-errors --explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable'
SNAPSHOT = '--explicit-target-dependency-import-check error -Xswiftc -require-explicit-sendable'
ASSETS = Path(__file__).resolve().parents[3] / 'skills/delivering-swift-services/assets'


def read_yaml(path):
    return yaml.load(path.read_text(), Loader=WorkflowLoader)


def verify(root, provider=None, no_tests=False, traits=False, foundation_exception=None, excluded=(), warning_exception=None):
    failures = []
    def need(condition, message):
        if not condition:
            failures.append(message)
    root = Path(root).resolve()
    workflow_paths = sorted((root / '.github/workflows').glob('*.y*ml'))
    workflows = {str(p.relative_to(root)): read_yaml(p) for p in workflow_paths}
    need(bool(workflows), 'No workflows')
    for path, workflow in workflows.items():
        need('schedule' not in workflow.get('on', {}), f'{path}: scheduled CI')
        for name, job in workflow.get('jobs', {}).items():
            need('api' not in name.lower() or 'break' not in name.lower(), f'{path}: API-breakage job')
            need('macos' not in json.dumps(job).lower(), f'{path}: macOS job')
            need(not job.get('continue-on-error'), f'{path}/{name}: hidden failure')
            for step in job.get('steps', []):
                run = step.get('run', '')
                need('diagnose-api-breaking' not in run, f'{path}: API-diff command')
                need(not any(flag in run for flag in ['--disable-automatic-resolution', '--force-resolved-versions']), f'{path}: locked library resolution')
                need('|| true' not in run and not step.get('continue-on-error'), f'{path}: hidden command failure')
    pr = [w for w in workflows.values() if {'opened', 'reopened', 'synchronize'} <= set((w.get('on', {}).get('pull_request') or {}).get('types', [])) and any(j.get('uses') == SOUNDNESS for j in w.get('jobs', {}).values())]
    main = [w for w in workflows.values() if 'main' in (w.get('on', {}).get('push') or {}).get('branches', [])]
    need(len(pr) == 1, 'Exactly one PR code workflow with soundness required')
    need(len(main) == 1, 'Exactly one main push workflow required')
    def expanded(jobs):
        result = list(jobs.values())
        for job in list(result):
            uses = job.get('uses', '')
            if uses.startswith('./'):
                target = workflows.get(uses[2:])
                need(target is not None, f'Missing reusable workflow {uses}')
                if target:
                    result.extend(target.get('jobs', {}).values())
        return result
    if warning_exception:
        agent = (root / 'AGENTS.md').read_text() if (root / 'AGENTS.md').exists() else ''
        need(warning_exception in agent and 'generator' in agent.lower(), 'Generated diagnostic exception not documented')
    for event, selected in [('PR', pr), ('main', main)]:
        if len(selected) != 1:
            continue
        jobs = selected[0].get('jobs', {})
        sdk = [j for j in jobs.values() if j.get('uses') == NIO + 'static_sdk.yml@main']
        need(len(sdk) == (1 if event == 'PR' else 0), f'{event}: static SDK event coverage')
        if sdk:
            need(set(sdk[0]) <= {'name', 'uses'}, 'Static SDK must use unmodified defaults without dependencies/overrides')
        release = [j for j in jobs.values() if j.get('uses') == NIO + 'release_builds.yml@main']
        need(len(release) == 1, f'{event}: release matrix missing')
        for job in release:
            config = job.get('with', {})
            need(config.get('minimum_swift_version') == '6.3' and config.get('linux_6_2_enabled') is False, f'{event}: release tools floor/filter')
            for suffix in ('6_3', '6_4', 'nightly_next', 'nightly_main'):
                need(config.get('linux_' + suffix + '_enabled', True) is True, f'{event}: disabled release compiler {suffix}')
        links = [j for j in jobs.values() if j.get('uses') == FOUNDATION]
        if foundation_exception:
            need(not links, f'{event}: exception expects omitted full-Foundation gate')
            agent = (root / 'AGENTS.md').read_text() if (root / 'AGENTS.md').exists() else ''
            need(foundation_exception.lower() in agent.lower() and 'Foundation' in agent, 'Foundation exception not recorded in AGENTS.md')
        else:
            need({j.get('with', {}).get('swift_image') for j in links} == {'swift:6.3-noble', 'swift:6.4-noble'}, f'{event}: both Foundation Noble versions required')
            for job in links:
                need(set(job.get('with', {}).get('excluded_products', '').split()) == set(excluded), f'{event}: product exclusion too broad/missing')
        unit = [j for j in jobs.values() if j.get('uses') == NIO + 'unit_tests.yml@main']
        if not provider and not no_tests:
            need(len(unit) == 1, f'{event}: standard unit matrix missing')
            for job in unit:
                config = job.get('with', {})
                need(config.get('minimum_swift_version') == '6.3' and config.get('linux_6_2_enabled') is False, f'{event}: unit tools floor/filter')
                for suffix in ('6_3', '6_4', 'nightly_next', 'nightly_main'):
                    need(config.get('linux_' + suffix + '_arguments_override') == (SNAPSHOT if 'nightly' in suffix else STABLE), f'{event}: {suffix} compiler flags')
                    need(config.get('linux_' + suffix + '_enabled', True) is True, f'{event}: disabled test compiler {suffix}')
        else:
            need(not unit, f'{event}: generic tests cannot cover this exception')
            custom = [j for j in expanded(jobs) if 'matrix' in j.get('strategy', {}) and 'container' in j]
            need(len(custom) == 1, f'{event}: replacement compiler matrix missing/ambiguous')
            for job in custom:
                entries = job['strategy']['matrix'].get('include', [])
                need(len(entries) == 4, f'{event}: replacement requires four toolchains')
                images = {e.get('image', '') for e in entries}
                need('swift:6.3-noble' in images and ('swift:6.4-resolute' in images or 'swift:6.4-noble' in images) and any('nightly-main' in s for s in images) and any('nightly-6.4.x' in s for s in images), f'{event}: replacement compiler coverage')
                def expected_flags(entry):
                    image = entry.get('image', '')
                    flags = SNAPSHOT if 'nightly' in image else STABLE
                    if warning_exception and image.startswith('swift:6.4-'):
                        flags += ' -Xswiftc -Wwarning -Xswiftc ' + warning_exception
                    return flags
                need(all(e.get('arguments') == expected_flags(e) for e in entries), f'{event}: replacement flags')
                runs = '\n'.join(s.get('run', '') for s in job.get('steps', []))
                if provider == 'postgres':
                    pg = job.get('services', {}).get('postgres', {})
                    need(pg.get('image') == 'postgres:18-alpine', f'{event}: real PostgreSQL 18 service missing')
                    need('pg_isready -h 127.0.0.1' in pg.get('options', ''), f'{event}: TCP readiness required')
                    env = job.get('env', {})
                    server = pg.get('env', {})
                    need(env.get('POSTGRES_HOST') == 'postgres' and str(env.get('POSTGRES_PORT')) == '5432', f'{event}: database hostname/port')
                    need(env.get('POSTGRES_PASSWORD') == server.get('POSTGRES_PASSWORD') and env.get('POSTGRES_USER') == server.get('POSTGRES_USER', 'postgres') and env.get('POSTGRES_DB') == server.get('POSTGRES_DB', 'postgres'), f'{event}: database credentials mismatch')
                    need('swift test --parallel' in runs and '${{ matrix.arguments }}' in runs, f'{event}: provider tests do not run')
                if no_tests:
                    need('swift test' not in runs and 'swift build' in runs and '--package-path' in runs, f'{event}: build and downstream consumer required')
                    if traits:
                        need(sum('--disable-default-traits' in s.get('run', '') for s in job.get('steps', [])) >= 2, f'{event}: both custom transport library and consumer builds required')
    soundness = [j for w in pr for j in w['jobs'].values() if j.get('uses') == SOUNDNESS]
    for job in soundness:
        config = job.get('with', {})
        need(config.get('api_breakage_check_enabled') is False and config.get('license_header_check_enabled') is True, 'Soundness API/header settings')
        need(bool(config.get('docs_check_targets')), 'DocC targets missing')
        need(config.get('format_check_container_image') == 'swift:6.3-noble', 'Formatter toolchain mismatch')
        need(not any(v is False for k, v in config.items() if k.endswith('_enabled') and k != 'api_breakage_check_enabled'), 'Soundness check silently disabled')
    labels = [w for w in workflows.values() if {'labeled', 'unlabeled', 'opened', 'reopened', 'synchronize'} <= set((w.get('on', {}).get('pull_request') or {}).get('types', []))]
    need(any(s.get('uses') == 'apple/swift-nio/.github/actions/pull_request_semver_label_checker@main' for w in labels for j in w.get('jobs', {}).values() for s in j.get('steps', [])), 'SemVer label gate missing')
    need(all((w.get('permissions') or {}).get('pull-requests') == 'read' for w in labels) and bool(labels), 'SemVer label workflow cannot read pull requests')
    dep_path = root / '.github/dependabot.yml'
    dep = read_yaml(dep_path) if dep_path.exists() else {}
    need(any(u.get('package-ecosystem') == 'github-actions' and u.get('directory') == '/' and u.get('schedule', {}).get('interval') == 'weekly' and u.get('target-branch', 'main') == 'main' and 'semver/none' in u.get('labels', []) for u in dep.get('updates', [])), 'Weekly Actions Dependabot/label policy missing')
    fmt = root / '.swift-format'
    need(fmt.exists() and fmt.read_bytes() == (ASSETS / 'sample.swift-format').read_bytes(), 'Sample formatter required')
    template = root / '.license_header_template'
    need(template.exists(), 'Compact license template missing')
    if template.exists():
        lines = template.read_text().splitlines()
        need(len(lines) == 3 and 'Copyright' in lines[0] and 'YEARS' in lines[0] and 'SPDX-License-Identifier:' in lines[1], 'Three-line SPDX template required')
    ignored = (root / '.gitignore').read_text().splitlines() if (root / '.gitignore').exists() else []
    need('Package.resolved' in ignored, 'Library must ignore all resolved files by name')
    tracked = subprocess.run(['git', 'ls-files'],cwd=root,text=True,capture_output=True)
    # In a standalone eval workspace without git, also inspect files on disk.
    files = tracked.stdout.splitlines() if tracked.returncode == 0 else [str(p.relative_to(root)) for p in root.rglob('*') if p.is_file() and '.build' not in p.parts]
    need(not any(Path(f).name == 'Package.resolved' for f in files), 'Tracked resolved file')
    if no_tests:
        need(not any(f.startswith('Tests/') and f.endswith('.swift') for f in files), 'Placeholder runtime tests added to no-test package')
        consumers = list((root / '.github/Fixtures').glob('*/Sources/**/*.swift'))
        need(bool(consumers) and any('public ' in p.read_text() for p in consumers), 'Actual exported API consumer probe missing')
        if traits:
            manifests = list((root / '.github/Fixtures').glob('*/Package.swift'))
            need(any('.when(traits:' in p.read_text() and '.package(path:' in p.read_text() for p in manifests), 'Consumer must explicitly forward traits to local checkout')
    if template.exists():
        normalized_template = template.read_text().replace('@@', '//').splitlines()
        def normalize_years(line):
            return re.sub(r'20\d{2}(?: ?[-–] ?20\d{2})?', 'YEARS', line)
        # Inspect owned source, not dependency or generated build trees. Even ignored
        # manifests must carry their compact header after the mandatory directive.
        ignore_path = root / '.licenseignore'
        exclusions = ignore_path.read_text().splitlines() if ignore_path.exists() else []
        need('Package.swift' in exclusions and 'LICENSE' in exclusions, 'Narrow upstream license exclusions required')
        need(not any(x in exclusions for x in ('*', '*.swift', 'Sources/**', 'Tests/**')), 'Broad header exclusions conceal source')
        for directory, dirs, names in os.walk(root):
            dirs[:] = [d for d in dirs if d not in ('.git', '.build', '.swiftpm', 'Packages', 'DerivedData')]
            for name in names:
                path = Path(directory) / name
                if path.suffix not in ('.swift', '.proto'):
                    continue
                content = path.read_text().splitlines()
                if name == 'Package.swift':
                    need(bool(content) and content[0].startswith('// swift-tools-version:'), str(path) + ': tools directive must be first')
                    content = content[1:]
                need([normalize_years(line) for line in content[:3]] == normalized_template, str(path) + ': header does not match license template')
    need((root / 'AGENTS.md').exists(), 'Repository profile missing')
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('workspace', type=Path)
    parser.add_argument('--provider', choices=['postgres'])
    parser.add_argument('--no-tests', action='store_true')
    parser.add_argument('--traits', action='store_true')
    parser.add_argument('--foundation-exception')
    parser.add_argument('--excluded-products', nargs='*', default=[])
    parser.add_argument('--warning-exception', choices=['UnusedImportAccess'])
    args = parser.parse_args()
    failures = verify(args.workspace, args.provider, args.no_tests, args.traits, args.foundation_exception, args.excluded_products, args.warning_exception)
    if failures:
        for failure in failures:
            print('FAIL:', failure)
        raise SystemExit(1)
    print('PASS: library CI artifact contract')


if __name__ == '__main__':
    main()
