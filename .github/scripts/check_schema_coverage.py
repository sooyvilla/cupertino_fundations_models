import json
import subprocess
from pathlib import Path


def check(report, root):
    payload = json.loads(report.read_text(encoding='utf-8'))
    results = []
    for name in ('SchemaMapper', 'StructuredSnapshotMapper', 'SessionHistoryCodec', 'AvailabilityMonitor', 'TextModelLanguageMapper'):
        expected = (root / f'darwin/cupertino_fundations_models/Sources/cupertino_fundations_models/{name}.swift').resolve()
        files = [entry for data in payload.get('data', []) for entry in data.get('files', [])
                 if Path(entry.get('filename', '')).resolve() == expected]
        if len(files) != 1:
            raise ValueError(f'The report must contain the production {name} exactly once.')
        summary = files[0]['summary']
        for kind in ('lines', 'functions', 'regions'):
            counts = summary[kind]
            total, covered = counts['count'], counts['covered']
            if type(total) is not int or type(covered) is not int or total <= 0 or covered != total:
                uncovered = sorted({f'{segment[0]}:{segment[1]}' for segment in files[0].get('segments', [])
                                    if len(segment) >= 5 and segment[2] == 0 and segment[3] and segment[4]})
                detail = f' Uncovered region starts: {", ".join(uncovered)}.' if uncovered else ''
                raise ValueError(f'Native {name} {kind} coverage must be exactly 100%: {covered}/{total}.{detail}')
        lines = summary['lines']['count']
        results.append(f'Native {name} coverage: {lines}/{lines} lines (100%); functions and regions 100%.')
    return '\n'.join(results)


def main():
    root = Path.cwd().resolve()
    result = subprocess.run(
        ['swift', 'test', '--package-path', 'darwin', '--show-codecov-path'],
        check=True, capture_output=True, text=True,
    )
    report = Path(result.stdout.strip())
    try:
        print(check(report, root))
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(str(error))


if __name__ == '__main__':
    main()
