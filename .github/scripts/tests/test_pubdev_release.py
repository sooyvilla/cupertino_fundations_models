import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pubdev_release


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.previous_directory = Path.cwd()
        os.chdir(self.root)
        self.addCleanup(os.chdir, self.previous_directory)
        self.manifest = 'name: cupertino_fundations_models\nversion: 0.5.0\n'
        Path('pubspec.yaml').write_text(self.manifest)
        Path('event.json').write_text(json.dumps({'before': 'a' * 40}))
        self.environment = patch.dict(os.environ, {
            'GITHUB_REF': 'refs/heads/main',
            'GITHUB_SHA': 'b' * 40,
            'GITHUB_EVENT_PATH': str(self.root / 'event.json'),
            'GITHUB_OUTPUT': str(self.root / 'outputs'),
            'GITHUB_STEP_SUMMARY': str(self.root / 'summary'),
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.git = patch.object(pubdev_release, 'git', side_effect=lambda *args: 'version: 0.4.4\n' if args[0] == 'show' else 'b' * 40).start()
        self.published = patch.object(pubdev_release, 'published', return_value=False).start()
        self.process = patch.object(pubdev_release.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', '')).start()
        self.addCleanup(patch.stopall)

    def run_release(self):
        with patch('sys.stdout', new=io.StringIO()):
            pubdev_release.main()
        return Path('outputs').read_text()

    def test_main_version_change_requests_tag_without_publishing(self):
        outputs = self.run_release()
        self.assertIn('tag=v0.5.0', outputs)
        self.assertIn('create_tag=true', outputs)
        self.assertIn('publish=false', outputs)

    def test_unchanged_version_skips_without_contacting_pub(self):
        self.git.side_effect = None
        self.git.return_value = 'version: 0.5.0\n'
        self.assertIn('create_tag=false', self.run_release())
        self.published.assert_not_called()

    def test_already_published_version_skips(self):
        self.published.return_value = True
        self.assertIn('publish=false', self.run_release())

    def test_tag_on_main_can_publish(self):
        os.environ['GITHUB_REF'] = 'refs/tags/v0.5.0'
        self.process.return_value = subprocess.CompletedProcess([], 0, '', '')
        outputs = self.run_release()
        self.assertIn('create_tag=false', outputs)
        self.assertIn('publish=true', outputs)

    def test_tag_must_match_manifest(self):
        os.environ['GITHUB_REF'] = 'refs/tags/v0.4.4'
        with self.assertRaisesRegex(SystemExit, 'exactly match'):
            self.run_release()

    def test_tag_outside_main_cannot_publish(self):
        os.environ['GITHUB_REF'] = 'refs/tags/v0.5.0'
        with self.assertRaisesRegex(SystemExit, 'belong to main'):
            self.run_release()

    def test_tag_cannot_be_moved_to_another_commit(self):
        self.process.return_value = subprocess.CompletedProcess([], 0, 'c' * 40, '')
        with self.assertRaisesRegex(SystemExit, 'another commit'):
            self.run_release()

    def test_existing_correct_tag_requests_original_run_recovery(self):
        self.process.return_value = subprocess.CompletedProcess([], 0, 'b' * 40, '')
        outputs = self.run_release()
        self.assertIn('create_tag=false', outputs)
        self.assertIn('original tag workflow', Path('summary').read_text())

    def test_unknown_previous_commit_fails_closed(self):
        Path('event.json').write_text(json.dumps({'before': '0' * 40}))
        with self.assertRaisesRegex(SystemExit, 'previous main commit'):
            self.run_release()

    def test_checkout_must_match_push(self):
        self.git.side_effect = lambda *args: 'version: 0.4.4\n' if args[0] == 'show' else 'c' * 40
        with self.assertRaisesRegex(SystemExit, 'does not match'):
            self.run_release()

    def test_pr_ref_cannot_release(self):
        os.environ['GITHUB_REF'] = 'refs/pull/1/merge'
        with self.assertRaisesRegex(SystemExit, 'require a main push'):
            self.run_release()

    def test_invalid_versions_fail(self):
        for version in ['01.5.0', '0.5.0-beta.01', '0.5']:
            with self.subTest(version=version):
                Path('pubspec.yaml').write_text(self.manifest.replace('0.5.0', version))
                with self.assertRaises(SystemExit):
                    self.run_release()

    def test_manifest_requires_one_literal_field(self):
        for manifest in ['version: $VERSION', 'version: 0.5.0\nversion: 0.5.1']:
            with self.subTest(manifest=manifest), self.assertRaises(SystemExit):
                pubdev_release.field(manifest, 'version')
        self.assertEqual(pubdev_release.field('version: "0.5.0" # stable', 'version'), '0.5.0')

    def test_unexpected_package_fails(self):
        Path('pubspec.yaml').write_text(self.manifest.replace(pubdev_release.PACKAGE, 'other'))
        with self.assertRaisesRegex(SystemExit, 'Package name differs'):
            self.run_release()


class PubStatusTests(unittest.TestCase):
    def test_only_not_found_means_unpublished(self):
        for code in [404, 403, 429, 503]:
            with self.subTest(code=code), patch.object(pubdev_release, 'urlopen', side_effect=HTTPError('https://pub.dev', code, 'error', {}, None)):
                if code == 404:
                    self.assertFalse(pubdev_release.published('0.5.0'))
                else:
                    with self.assertRaises(SystemExit):
                        pubdev_release.published('0.5.0')

    def test_network_and_malformed_responses_fail_closed(self):
        for failure in [URLError('offline'), TimeoutError(), ValueError('bad JSON')]:
            with self.subTest(failure=failure), patch.object(pubdev_release, 'urlopen', side_effect=failure), self.assertRaises(SystemExit):
                pubdev_release.published('0.5.0')

    def test_version_response_must_match_requested_version(self):
        for data in [{'version': '0.5.0'}, {'version': '0.4.4'}, []]:
            with self.subTest(data=data), patch.object(pubdev_release, 'urlopen', return_value=io.StringIO(json.dumps(data))):
                if data == {'version': '0.5.0'}:
                    self.assertTrue(pubdev_release.published('0.5.0'))
                else:
                    with self.assertRaises(SystemExit):
                        pubdev_release.published('0.5.0')


if __name__ == '__main__':
    unittest.main()
