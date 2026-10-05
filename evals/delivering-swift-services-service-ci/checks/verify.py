#!/usr/bin/env python3
"""Verify a service's effective CI gates without executing GitHub workflows. Requires PyYAML."""
import argparse
import json
import re
import subprocess
import os
import tempfile
from pathlib import Path

import yaml


class WorkflowLoader(yaml.SafeLoader):
    pass


WorkflowLoader.yaml_implicit_resolvers = {
    key: [(tag, value) for tag, value in values if tag != 'tag:yaml.org,2002:bool']
    for key, values in yaml.SafeLoader.yaml_implicit_resolvers.items()
}
WorkflowLoader.add_implicit_resolver(
    'tag:yaml.org,2002:bool', re.compile(r'^(?:true|false|True|False|TRUE|FALSE)$'), list('tTfF')
)


def verify(root, worker=False):
    root = Path(root).resolve()
    failures = []

    def need(condition, message):
        if not condition:
            failures.append(message)

    def read(path):
        return yaml.load(path.read_text(), Loader=WorkflowLoader)

    workflows = {str(p.relative_to(root)): read(p) for p in (root / '.github/workflows').glob('*.y*ml')}

    def resolve(value, bindings):
        if isinstance(value, str):
            match = re.fullmatch(r'\$\{\{\s*inputs\.(\w+)\s*\}\}', value)
            if match:
                return bindings.get(match[1], value)
            return value
        if isinstance(value, dict):
            return {k: resolve(v, bindings) for k, v in value.items()}
        if isinstance(value, list):
            return [resolve(v, bindings) for v in value]
        return value

    def expanded(workflow, bindings=None, seen=()):
        bindings = bindings or {}
        jobs = []
        for name, original in workflow.get('jobs', {}).items():
            job = resolve(original, bindings)
            jobs.append(job)
            uses = job.get('uses', '')
            if uses.startswith('./'):
                path = uses[2:]
                need(path in workflows and path not in seen, f'Invalid recursive/missing workflow {path}')
                if path in workflows and path not in seen:
                    child = workflows[path]
                    specs = (child.get('on', {}).get('workflow_call') or {}).get('inputs', {})
                    values = {k: v.get('default') for k, v in specs.items()}
                    values.update(job.get('with', {}))
                    jobs.extend(expanded(child, values, (*seen, path)))
        return jobs

    for path, workflow in workflows.items():
        events = workflow.get('on', {})
        if 'schedule' in events:
            # Existing registry housekeeping may remain separate from validation.
            need('cleanup' in path and 'swift test' not in json.dumps(workflow), f'{path}: scheduled CI')
        for job in workflow.get('jobs', {}).values():
            need(not job.get('continue-on-error'), f'{path}: hidden job failure')
            need(not job.get('services'), f'{path}: infrastructure fixture added')
            uses = job.get('uses', '')
            if uses and not uses.startswith('./'):
                need(bool(re.search(r'@[0-9a-f]{40}$', uses)), f'{path}: unpinned reusable workflow')
            for step in job.get('steps', []):
                uses = step.get('uses', '')
                if uses and not uses.startswith('./'):
                    need(bool(re.search(r'@[0-9a-f]{40}$', uses)), f'{path}: unpinned action')
                text = step.get('run', '')
                need('diagnose-api-breaking' not in text and '|| true' not in text and not step.get('continue-on-error'), f'{path}: API-diff/hidden failure')

    selections = {
        'PR': [w for w in workflows.values() if 'pull_request' in w.get('on', {})],
        'develop': [w for w in workflows.values() if 'develop' in (w.get('on', {}).get('push') or {}).get('branches', [])],
        'main': [w for w in workflows.values() if 'main' in (w.get('on', {}).get('push') or {}).get('branches', [])],
    }
    agent = (root / 'AGENTS.md').read_text() if (root / 'AGENTS.md').exists() else ''
    format_file = root / '.swift-format'
    need(format_file.exists(), 'Missing formatter')
    standard = Path(__file__).resolve().parents[3] / 'skills/delivering-swift-services/assets/sample.swift-format'
    if not (format_file.exists() and format_file.read_bytes() == standard.read_bytes()):
        need('formatter' in agent.lower(), 'Formatter differs from the sample and is not recorded')
    header_exception = 'Xcode' in agent
    if not header_exception:
        need((root / '.license_header_template').exists(), 'Default compact header template missing')
    need(bool(agent), 'Repository profile missing')
    need((root / 'Package.resolved').exists(), 'Application lockfile missing')
    tracked = subprocess.run(['git', 'ls-files', 'Package.resolved'], cwd=root, text=True, capture_output=True)
    if (root / '.git').exists():
        need(bool(tracked.stdout.strip()), 'Application lockfile not tracked')
    for event, selected in selections.items():
        need(len(selected) == 1, f'{event}: exactly one pipeline required')
        if len(selected) != 1:
            continue
        flow = selected[0]
        need(flow.get('permissions', {}).get('contents') == 'read', f'{event}: read-only default required')
        concurrency = flow.get('concurrency', {})
        need(concurrency.get('cancel-in-progress') is (event == 'PR'), f'{event}: wrong cancellation policy')
        if event == 'PR':
            types = (flow['on']['pull_request'] or {}).get('types', [])
            need({'opened', 'reopened', 'synchronize'} <= set(types), 'PR event coverage')
            need(not any(j.get('permissions', {}).get('packages') == 'write' for j in flow.get('jobs', {}).values()), 'PR package-write permission')
        else:
            need(event in concurrency.get('group', ''), f'{event}: rollout group must be per branch')
        jobs = expanded(flow)
        soundness = [j for j in jobs if '/soundness.yml@' in j.get('uses', '')]
        need(len(soundness) == 1, f'{event}: missing soundness')
        for j in soundness:
            inputs = j.get('with', {})
            need(inputs.get('api_breakage_check_enabled') is False and inputs.get('docs_check_enabled') is False, f'{event}: executable API/DocC checks enabled')
            need(inputs.get('license_header_check_enabled') is (not header_exception), f'{event}: header profile mismatch')
            need(inputs.get('format_check_container_image') == 'swift:6.3-noble', f'{event}: formatter toolchain mismatch')
        tests = [j for j in jobs if '/swift_package_test.yml@' in j.get('uses', '')]
        need(len(tests) == 1, f'{event}: missing package tests')
        for j in tests:
            inputs = j.get('with', {})
            for key, expected in [('linux_swift_versions', ['6.3']), ('linux_os_versions', ['noble']), ('linux_host_archs', ['aarch64']), ('linux_static_sdk_versions', ['6.3'])]:
                need(json.loads(inputs.get(key, '[]')) == expected, f'{event}: wrong {key}')
            need(inputs.get('enable_linux_static_sdk_build') is True, f'{event}: static SDK missing')
            need(all(inputs.get(k) is False for k in ['enable_macos_checks', 'enable_ios_checks', 'enable_windows_checks']), f'{event}: unwanted platform')
            need('swift test' in inputs.get('linux_build_command', '') and '--disable-automatic-resolution' in inputs.get('linux_build_command', ''), f'{event}: unlocked/missing tests')
            static = inputs.get('linux_static_sdk_build_command', '')
            need(all(s in static for s in ['--configuration release', '--disable-automatic-resolution', '--product']), f'{event}: wrong static build')
            flags = inputs.get('swift_flags', '')
            need(all(s in flags for s in ['-warnings-as-errors', '--explicit-target-dependency-import-check error', '-require-explicit-sendable']), f'{event}: compiler checks missing')
        need(any('actionlint' in str(step) and 'sha256sum' in step.get('run', '') for j in jobs for step in j.get('steps', [])), f'{event}: verified actionlint missing')
        image_calls = [j for j in flow.get('jobs', {}).values() if j.get('uses', '').endswith('/image.yml')]
        need(len(image_calls) == 1, f'{event}: image workflow missing')
        for j in image_calls:
            need(j.get('with', {}).get('worker', False) is worker, f'{event}: worker command coverage')
            need(j.get('with', {}).get('publish', False) is (event != 'PR'), f'{event}: PR/publication boundary')
            if event != 'PR':
                need('checks' in j.get('needs', []) and j.get('permissions', {}).get('packages') == 'write', f'{event}: publication must wait for checks')
        if event != 'PR':
            deploy = flow.get('jobs', {}).get('deploy', {})
            need('publish' in deploy.get('needs', []), f'{event}: deployment must wait for publication')
    image = workflows.get('.github/workflows/image.yml', {})
    steps = [s for j in image.get('jobs', {}).values() for s in j.get('steps', [])]
    build = [s for s in steps if 'docker/build-push-action@' in s.get('uses', '')]
    need(len(build) == 1 and build[0].get('with', {}).get('platforms') == 'linux/arm64' and build[0].get('with', {}).get('load') is True and build[0].get('with', {}).get('push') is False, 'Native final image must be loaded before validation')
    smoke_positions = [i for i, s in enumerate(steps) if 'check-image.sh' in s.get('run', '')]
    publish_positions = [i for i, s in enumerate(steps) if 'docker push' in s.get('run', '')]
    need(bool(smoke_positions) and bool(publish_positions) and max(smoke_positions) < min(publish_positions), 'Image validation must precede publication')
    need(all('inputs.publish' in steps[i].get('if', '') for i in publish_positions), 'Publication must be conditional')
    smoke = root / '.github/scripts/check-image.sh'
    need(smoke.exists(), 'Missing image validation helper')
    if smoke.exists():
        s = smoke.read_text()
        need(all(x in s for x in ['--entrypoint ldd', 'not found', 'serve --help', 'worker run --help', '.Config.User']), 'Image smoke coverage incomplete')
        failures.extend(verify_smoke(smoke))
    cf = (root / 'Containerfile').read_text() if (root / 'Containerfile').exists() else ''
    need('FROM swift:6.3-noble' in cf, 'Image toolchain differs from CI')
    need('swift package --disable-automatic-resolution resolve' in cf and cf.count('--disable-automatic-resolution') >= 2, 'Unlocked Containerfile resolution/build')
    need(all(flag in cf for flag in ['-warnings-as-errors', '--explicit-target-dependency-import-check error', '-require-explicit-sendable']), 'Release image compiler checks missing')
    need('COPY --from=build' in cf and '/staging /app' in cf, 'Final image drops staged resources')
    makefile = root / 'Makefile'
    if makefile.exists():
        for line in makefile.read_text().splitlines():
            if 'swift build' in line:
                need('--disable-automatic-resolution' in line, 'Unlocked local Makefile build')
    dependabot = root / '.github/dependabot.yml'
    updates = read(dependabot).get('updates', []) if dependabot.exists() else []
    need({u.get('package-ecosystem') for u in updates} == {'swift', 'github-actions'} and all(u.get('target-branch') == 'develop' and u.get('schedule', {}).get('interval') == 'weekly' for u in updates), 'Dependency updates do not follow service policy')
    return failures


def verify_smoke(script):
    """Exercise the helper's process boundary without a real Docker daemon."""
    failures = []
    with tempfile.TemporaryDirectory(prefix='service-ci-smoke-') as directory:
        root = Path(directory)
        docker = root / 'docker'
        docker.write_text('''#!/bin/bash
set -eu
printf '%s\\n' "$*" >> "$CALLS"
if [[ $1 == image ]]; then
  if [[ $SCENARIO == root ]]; then echo root; else echo service; fi
elif [[ $* == *'--entrypoint ldd'* ]]; then
  case "$SCENARIO" in
    missing) echo 'libFoundation.so => not found' ;;
    static) echo 'not a dynamic executable'; exit 1 ;;
    broken-ldd) echo 'cannot inspect executable'; exit 1 ;;
    *) echo 'libc.so.6 => /lib/libc.so.6' ;;
  esac
elif [[ $SCENARIO == worker-fails && $* == *'worker run --help'* ]]; then
  exit 2
fi
''')
        docker.chmod(0o755)
        for scenario, success in [('valid', True), ('static', True), ('missing', False),
                                  ('root', False), ('broken-ldd', False), ('worker-fails', False)]:
            calls = root / f'{scenario}.calls'
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                       SCENARIO=scenario, CALLS=str(calls))
            result = subprocess.run(['bash', str(script), 'example:ci', 'example-service', 'true'],
                                    env=env, capture_output=True, text=True, timeout=10)
            if (result.returncode == 0) != success:
                failures.append(f'Runtime helper mishandles {scenario}')
            if success and (not calls.exists() or 'worker run --help' not in calls.read_text()):
                failures.append('Runtime helper does not execute worker command')
        calls = root / 'no-worker.calls'
        env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                   SCENARIO='valid', CALLS=str(calls))
        result = subprocess.run(['bash', str(script), 'example:ci', 'example-service', 'false'],
                                env=env, capture_output=True, text=True, timeout=10)
        if result.returncode != 0 or 'worker run --help' in calls.read_text():
            failures.append('Runtime helper runs absent worker command')
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('workspace', type=Path)
    parser.add_argument('--worker', action='store_true')
    args = parser.parse_args()
    failures = verify(args.workspace, args.worker)
    for failure in failures:
        print('FAIL:', failure)
    if failures:
        raise SystemExit(1)
    print('PASS: service CI artifact contract')


if __name__ == '__main__':
    main()
