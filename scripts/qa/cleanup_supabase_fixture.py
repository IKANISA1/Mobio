#!/usr/bin/env python3
"""Remove only exact project-labelled resources of an owned Mobio fixture.

Supabase CLI stop uses a daemon prune operation. Concurrent fixture cleanup can
make that operation fail. This helper never prunes or touches other projects.
"""
import argparse
import json
import re
import subprocess


class FixtureCleanupError(RuntimeError):
    pass


def docker_output(arguments):
    completed = subprocess.run(['docker', *arguments], capture_output=True,
                               text=True, timeout=60)
    if completed.returncode:
        raise FixtureCleanupError('Owned Docker operation failed: ' + arguments[0])
    return completed.stdout


def cleanup_fixture(project, command=docker_output):
    if not re.fullmatch(r'mobio_[a-z0-9_]{1,80}', project):
        raise FixtureCleanupError('Invalid owned fixture project identifier')
    label = 'label=com.supabase.cli.project=' + project
    kinds = (
        ('container', ['ps', '-a'], ['inspect'], ['rm', '-f'],
         '{{json .Config.Labels}}', '{{.ID}}'),
        ('volume', ['volume', 'ls'], ['volume', 'inspect'], ['volume', 'rm'],
         '{{json .Labels}}', '{{.Name}}'),
        ('network', ['network', 'ls'], ['network', 'inspect'], ['network', 'rm'],
         '{{json .Labels}}', '{{.ID}}'),
    )
    owned = []
    # Validate all selected names and exact labels before the first removal.
    for kind, listing, inspection, removal, labels_format, identifier_format in kinds:
        identifiers = command([*listing, '--filter', label, '--format', identifier_format]).splitlines()
        for identifier in identifiers:
            name = command([*inspection, '--format', '{{.Name}}', identifier]).strip().removeprefix('/')
            labels = json.loads(command([*inspection, '--format', labels_format, identifier]))
            if (not name.startswith('supabase_') or not name.endswith('_' + project)
                    or not isinstance(labels, dict)
                    or labels.get('com.supabase.cli.project') != project):
                raise FixtureCleanupError('Owned fixture resource identity mismatch: ' + kind)
            owned.append((kind, identifier, name, removal))
    removed = []
    for kind, identifier, name, removal in owned:
        command([*removal, identifier])
        removed.append({'kind': kind, 'name': name})
    remaining = {}
    for kind, listing, _, _, _, identifier_format in kinds:
        remaining[kind] = command([*listing, '--filter', label, '--format', identifier_format]).splitlines()
    if any(remaining.values()):
        raise FixtureCleanupError('Owned fixture resources remain after cleanup')
    return {'project': project, 'removed': removed, 'remaining_owned': remaining}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True)
    args = parser.parse_args()
    try:
        result = cleanup_fixture(args.project)
    except (FixtureCleanupError, ValueError, subprocess.TimeoutExpired) as error:
        print(json.dumps({'project': args.project, 'cleanup_succeeded': False,
                          'error': str(error)}))
        return 1
    print(json.dumps({'cleanup_succeeded': True, **result}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
