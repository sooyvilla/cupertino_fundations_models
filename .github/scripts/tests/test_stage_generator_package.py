import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('stage_generator_package', Path(__file__).parents[1] / 'stage_generator_package.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class GeneratorStagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'repo'
        self.source = self.root / 'packages/cupertino_fundations_models_generator'
        self.source.mkdir(parents=True)
        for name in ('.pubignore', 'pubspec.yaml', 'build.yaml', 'README.md', 'CHANGELOG.md', 'LICENSE'):
            (self.source / name).write_text(name)
        (self.source / 'lib/src').mkdir(parents=True)
        (self.source / 'lib/src/builder.dart').write_text('const value = 1;')
        self.destination = Path(self.temp.name) / 'staged'

    def test_public_sources_are_staged_without_development_or_private_files(self):
        (self.source / 'private.json').write_text('private')
        (self.source / 'pubspec_overrides.yaml').write_text('not for publication')
        (self.source / 'test').mkdir()
        (self.source / 'test/fixture.dart').write_text('test only')
        module.stage(self.root, self.destination)
        self.assertEqual((self.destination / 'lib/src/builder.dart').read_text(), 'const value = 1;')
        self.assertTrue((self.destination / 'LICENSE').is_file())
        for name in ('private.json', 'pubspec_overrides.yaml', 'test/fixture.dart'):
            self.assertFalse((self.destination / name).exists())

    def test_existing_destination_is_never_overwritten(self):
        self.destination.mkdir()
        (self.destination / 'keep.txt').write_text('keep')
        with self.assertRaises(FileExistsError):
            module.stage(self.root, self.destination)
        self.assertEqual((self.destination / 'keep.txt').read_text(), 'keep')

    def test_repository_destination_is_rejected_before_creating_files(self):
        destination = self.root / 'staged'
        with self.assertRaises(ValueError):
            module.stage(self.root, destination)
        self.assertFalse(destination.exists())

    def test_local_core_override_is_explicit_and_points_to_the_source(self):
        module.stage(self.root, self.destination, local_core=True)
        text = (self.destination / 'pubspec_overrides.yaml').read_text()
        self.assertEqual(json.loads(text.split('path: ', 1)[1]), str(self.root))

    def test_symlinked_sources_are_rejected(self):
        external = Path(self.temp.name) / 'external.txt'
        external.write_text('not public')
        (self.source / 'lib/linked.dart').symlink_to(external)
        with self.assertRaises(ValueError):
            module.stage(self.root, self.destination)
        self.assertFalse((self.destination / 'lib/linked.dart').exists())


if __name__ == '__main__':
    unittest.main()
