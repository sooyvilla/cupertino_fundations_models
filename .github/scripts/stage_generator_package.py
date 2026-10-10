import argparse
import json
import shutil
import tempfile
from pathlib import Path


def stage(root, destination, local_core=False):
    source = root / 'packages/cupertino_fundations_models_generator'
    if destination.resolve().is_relative_to(root.resolve()):
        raise ValueError('Stage outside the repository to avoid ancestor publication exclusions.')
    destination.mkdir(parents=True, exist_ok=False)
    files = [source / name for name in (
        '.pubignore', 'pubspec.yaml', 'build.yaml', 'README.md', 'CHANGELOG.md', 'LICENSE'
    )]
    files.extend(source.glob('lib/**/*.dart'))
    for file in files:
        if file.is_symlink() or not file.resolve().is_relative_to(source.resolve()):
            raise ValueError('Only regular package source files may be staged.')
        target = destination / file.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, target)
    if local_core:
        (destination / 'pubspec_overrides.yaml').write_text(
            'dependency_overrides:\n  cupertino_fundations_models:\n    path: '
            + json.dumps(str(root)) + '\n', encoding='utf-8',
        )
    return destination


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--destination', type=Path)
    parser.add_argument('--local-core', action='store_true')
    arguments = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    destination = arguments.destination
    if destination is None:
        destination = Path(tempfile.mkdtemp(prefix='cupertino-generator-')) / 'package'
    print(stage(root, destination, arguments.local_core))


if __name__ == '__main__':
    main()
