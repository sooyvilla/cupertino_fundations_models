import os
import re
from pathlib import Path


def declaration_only(source):
    source = re.sub(r'/\*.*?\*/|//[^\n]*', '', source, flags=re.DOTALL)
    source = re.sub(r"(?:import|export|part|library)\s+[^;]+;", '', source)
    source = source.strip()
    if not source:
        return True
    interface = re.fullmatch(r'abstract interface class \w+\s*\{(.*)\}', source, re.DOTALL)
    if interface is None:
        return False
    methods = re.sub(r'[\w<>, ?]+\s+\w+\([^()]*\);', '', interface[1])
    return not methods.strip()


def check(report, root):
    records = {}
    for block in report.read_text(encoding='utf-8').split('end_of_record'):
        if not block.strip():
            continue
        fields = block.strip().splitlines()
        sources = [line[3:] for line in fields if line.startswith('SF:')]
        if len(sources) != 1:
            raise ValueError('Every coverage record must have exactly one source.')
        path = Path(sources[0])
        path = (path if path.is_absolute() else root / path).resolve()
        if not path.is_relative_to((root / 'lib').resolve()):
            raise ValueError(f'Unexpected coverage source: {sources[0]}')
        if path in records or not path.is_file():
            raise ValueError(f'Duplicate or missing source: {sources[0]}')
        lines = {}
        for field in fields:
            if field.startswith('DA:'):
                parts = field[3:].split(',')
                number, hits = int(parts[0]), int(parts[1])
                if number < 1 or hits < 0 or number in lines:
                    raise ValueError(f'Invalid line coverage in {sources[0]}')
                lines[number] = hits
        found = [int(line[3:]) for line in fields if line.startswith('LF:')]
        hit = [int(line[3:]) for line in fields if line.startswith('LH:')]
        if found != [len(lines)] or hit != [sum(value > 0 for value in lines.values())]:
            raise ValueError(f'Coverage counters disagree in {sources[0]}')
        if not lines:
            raise ValueError(f'Empty coverage record: {sources[0]}')
        records[path] = lines
    required = {path.resolve() for path in (root / 'lib').rglob('*.dart')
                if not declaration_only(path.read_text(encoding='utf-8'))}
    if not records or required - records.keys():
        missing = ', '.join(str(path.relative_to(root)) for path in sorted(required - records.keys()))
        raise ValueError(f'Missing executable Dart sources in coverage: {missing}')
    uncovered = [f'{path.relative_to(root)}:{number}' for path, lines in records.items()
                 for number, hits in lines.items() if hits == 0]
    total = sum(len(lines) for lines in records.values())
    if uncovered:
        raise ValueError(f'Coverage must be exactly 100%. Uncovered lines: {", ".join(uncovered)}')
    return f'Dart line coverage: {total}/{total} (100%) across {len(records)} executable sources.'


def main():
    root = Path.cwd().resolve()
    report = root / 'coverage/lcov.info'
    try:
        result = check(report, root)
    except (OSError, ValueError, IndexError) as error:
        raise SystemExit(str(error))
    print(result)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as output:
            output.write(f'{result}\n')


if __name__ == '__main__':
    main()
