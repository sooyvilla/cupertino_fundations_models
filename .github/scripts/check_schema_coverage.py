import argparse
import json
import re
import subprocess
from pathlib import Path


def check(report, root, runtime_profile=None):
    payload = json.loads(report.read_text(encoding='utf-8'))
    results = []
    for name in ('SchemaMapper', 'StructuredSnapshotMapper', 'SessionHistoryCodec', 'AvailabilityMonitor', 'TextModelLanguageMapper'):
        expected = (root / f'darwin/cupertino_fundations_models/Sources/cupertino_fundations_models/{name}.swift').resolve()
        files = [entry for data in payload.get('data', []) for entry in data.get('files', [])
                 if Path(entry.get('filename', '')).resolve() == expected]
        if len(files) != 1:
            raise ValueError(f'The report must contain the production {name} exactly once.')
        summary = files[0]['summary']
        uncovered = sorted({(segment[0], segment[1]) for segment in files[0].get('segments', [])
                            if len(segment) >= 5 and segment[2] == 0 and segment[3] and segment[4]})
        unavailable = set()
        if runtime_profile == 'macos27-before27.2' and name == 'SessionHistoryCodec':
            source = expected.read_text().splitlines()
            unavailable = {index - 1 for index, line in enumerate(source, 1)
                           if line.strip() == 'throw unsupported("Binary/data and unknown transcript entries are outside this history profile.")'
                           and index > 1 and source[index - 2].strip() == 'default:'}
            if len(unavailable) != 1:
                raise ValueError('The macOS27.0/27.1 profile requires the unchanged future-data rejection.')
        accepted_unavailable = len(uncovered) == 1 and {line for line, _ in uncovered} == unavailable
        for kind in ('lines', 'functions', 'regions'):
            counts = summary[kind]
            total, covered = counts['count'], counts['covered']
            if type(total) is not int or type(covered) is not int or total <= 0 or covered != total:
                if (type(total) is int and type(covered) is int and total > 0 and 0 <= covered <= total
                        and accepted_unavailable and kind in ('lines', 'regions') and total - covered == 1):
                    continue
                detail = f' Uncovered region starts: {", ".join(f"{line}:{column}" for line, column in uncovered)}.' if uncovered else ''
                raise ValueError(f'Native {name} {kind} coverage must be exactly 100%: {covered}/{total}.{detail}')
        lines = summary['lines']['count']
        covered = summary['lines']['covered']
        if covered == lines:
            results.append(f'Native {name} coverage: {lines}/{lines} lines (100%); functions and regions 100%.')
        else:
            results.append(f'Native {name} coverage: {covered}/{lines} lines ({100 * covered / lines:.2f}%); '
                           'functions 100%; one data-entry rejection region requires macOS27.2. '
                           'All other regions must be covered; the full source remains in the report.')
    return '\n'.join(results)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--respect-runtime-availability', action='store_true')
    args = parser.parse_args()
    runtime_profile = None
    if args.respect_runtime_availability:
        compiler = subprocess.run(['swift', '--version'], check=True, capture_output=True, text=True).stdout
        sdk = subprocess.run(['xcrun', '--sdk', 'macosx', '--show-sdk-version'], check=True, capture_output=True, text=True).stdout.strip()
        runtime = subprocess.run(['sw_vers', '-productVersion'], check=True, capture_output=True, text=True).stdout.strip()
        if re.search(r'Swift version 6\.4\b', compiler) and re.fullmatch(r'27\.2(?:\.\d+)*', sdk) and re.fullmatch(r'27\.[01](?:\.\d+)*', runtime):
            runtime_profile = 'macos27-before27.2'
    root = Path.cwd().resolve()
    result = subprocess.run(
        ['swift', 'test', '--package-path', 'darwin', '--show-codecov-path'],
        check=True, capture_output=True, text=True,
    )
    report = Path(result.stdout.strip())
    try:
        print(check(report, root, runtime_profile=runtime_profile))
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(str(error))


if __name__ == '__main__':
    main()
