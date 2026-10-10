import json
import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_schema_coverage


class NativeSchemaCoverageTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.report = self.root / 'coverage.json'
        self.filename = str(self.root / 'darwin/cupertino_fundations_models/Sources/cupertino_fundations_models/SchemaMapper.swift')
        self.entry = {'filename': self.filename, 'summary': {
            kind: {'count': 5, 'covered': 5} for kind in ('lines', 'functions', 'regions')
        }}
        self.snapshot = {'filename': self.filename.replace('SchemaMapper.swift', 'StructuredSnapshotMapper.swift'), 'summary': {
            kind: {'count': 7, 'covered': 7} for kind in ('lines', 'functions', 'regions')
        }}

        self.history = {'filename': self.filename.replace('SchemaMapper.swift', 'SessionHistoryCodec.swift'), 'summary': {
            kind: {'count': 9, 'covered': 9} for kind in ('lines', 'functions', 'regions')
        }}
        self.monitor = {'filename': self.filename.replace('SchemaMapper.swift', 'AvailabilityMonitor.swift'), 'summary': {
            kind: {'count': 11, 'covered': 11} for kind in ('lines', 'functions', 'regions')
        }}
        self.languages = {'filename': self.filename.replace('SchemaMapper.swift', 'TextModelLanguageMapper.swift'), 'summary': {
            kind: {'count': 13, 'covered': 13} for kind in ('lines', 'functions', 'regions')
        }}

    def check(self, entries, runtime_profile=None):
        self.report.write_text(json.dumps({'data': [{'files': entries + [self.snapshot, self.history, self.monitor, self.languages]}]}))
        return check_schema_coverage.check(self.report, self.root, runtime_profile=runtime_profile)

    def future_data_report(self):
        source = Path(self.history['filename'])
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_text('default:\nthrow unsupported("Binary/data and unknown transcript entries are outside this history profile.")\n')
        self.history['segments'] = [[1, 13, 0, True, True, False]]
        self.history['summary']['lines'] = {'count': 135, 'covered': 134}
        self.history['summary']['regions'] = {'count': 140, 'covered': 139}

    def test_runtime_profile_preserves_real_counts_and_default_stays_strict(self):
        self.future_data_report()
        with self.assertRaisesRegex(ValueError, 'SessionHistoryCodec lines'):
            self.check([self.entry])
        result = self.check([self.entry], runtime_profile='macos27-before27.2')
        self.assertIn('134/135 lines (99.26%)', result)
        self.assertIn('one data-entry rejection region requires macOS27.2', result)

    def test_runtime_profile_rejects_other_regions_functions_and_changed_source(self):
        self.future_data_report()
        for segments in [[], [[2, 13, 0, True, True, False]], self.history['segments'] * 2 + [[3, 13, 0, True, True, False]]]:
            with self.subTest(segments=segments):
                self.history['segments'] = segments
                with self.assertRaisesRegex(ValueError, '100%'):
                    self.check([self.entry], runtime_profile='macos27-before27.2')
        self.future_data_report()
        self.history['summary']['functions']['covered'] = 8
        with self.assertRaisesRegex(ValueError, 'functions'):
            self.check([self.entry], runtime_profile='macos27-before27.2')
        Path(self.history['filename']).write_text('changed source\n')
        with self.assertRaisesRegex(ValueError, 'unchanged future-data rejection'):
            self.check([self.entry], runtime_profile='macos27-before27.2')

    def test_runtime_profile_rejects_wrong_or_invalid_coverage_counts(self):
        self.future_data_report()
        for kind in ['lines', 'regions']:
            original = self.history['summary'][kind]
            for total, covered in [(135, 133), (0, 0), (1, -1), (True, True), (135, 136)]:
                with self.subTest(kind=kind, total=total, covered=covered):
                    self.history['summary'][kind] = {'count': total, 'covered': covered}
                    with self.assertRaisesRegex(ValueError, '100%'):
                        self.check([self.entry], runtime_profile='macos27-before27.2')
            self.history['summary'][kind] = original

    def test_cli_runtime_profile_is_limited_to_its_known_host_sdk_and_compiler(self):
        self.future_data_report()
        self.check([self.entry], runtime_profile='macos27-before27.2')
        for compiler, sdk, runtime, accepts in [('6.4', '27.2', '27.0', True), ('6.4', '27.2', '27.1.1', True),
                ('6.4', '27.2', '27.2', False), ('6.3', '27.2', '27.0', False),
                ('6.4', '26.6', '27.0', False), ('6.4', '27.2', '26.6', False)]:
            with self.subTest(compiler=compiler, sdk=sdk, runtime=runtime):
                output = io.StringIO()
                with patch.object(sys, 'argv', ['check_schema_coverage.py', '--respect-runtime-availability']), \
                        patch.object(check_schema_coverage.Path, 'cwd', return_value=self.root), \
                        patch.object(check_schema_coverage.subprocess, 'run', side_effect=[SimpleNamespace(stdout=f'Apple Swift version {compiler}'),
                            SimpleNamespace(stdout=sdk), SimpleNamespace(stdout=runtime), SimpleNamespace(stdout=str(self.report))]), \
                        contextlib.redirect_stdout(output):
                    if accepts:
                        check_schema_coverage.main()
                        self.assertIn('134/135 lines (99.26%)', output.getvalue())
                    else:
                        with self.assertRaisesRegex(SystemExit, '100%'):
                            check_schema_coverage.main()

    def test_complete_native_contract_report_passes(self):
        self.assertIn('5/5 lines (100%)', self.check([self.entry]))

    def test_missing_or_other_source_fails(self):
        with self.assertRaisesRegex(ValueError, 'exactly once'):
            self.check([])
        self.entry['filename'] = str(self.root / 'test/SchemaMapper.swift')
        with self.assertRaisesRegex(ValueError, 'production SchemaMapper'):
            self.check([self.entry])

    def test_duplicate_production_source_fails(self):
        with self.assertRaisesRegex(ValueError, 'exactly once'):
            self.check([self.entry, self.entry])

    def test_uncovered_lines_functions_or_regions_fail(self):
        for kind in ('lines', 'functions', 'regions'):
            with self.subTest(kind=kind):
                self.entry['summary'][kind]['covered'] = 4
                with self.assertRaisesRegex(ValueError, kind):
                    self.check([self.entry])
                self.entry['summary'][kind]['covered'] = 5

    def test_uncovered_regions_report_source_coordinates_without_counting_gaps(self):
        self.entry['summary']['lines']['covered'] = 4
        self.entry['segments'] = [[12, 3, 0, True, True, False], [12, 3, 0, True, True, False],
                                  [13, 2, 1, True, True, False], [14, 1, 0, False, True, False],
                                  [15, 1, 0, True, False, False]]
        with self.assertRaisesRegex(ValueError, r'Uncovered region starts: 12:3\.'):
            self.check([self.entry])

    def test_empty_negative_or_overstated_counters_fail(self):
        for total, covered in [(0, 0), (-1, -1), (5, 6), (5, -1), (True, True)]:
            with self.subTest(total=total, covered=covered):
                self.entry['summary']['lines'] = {'count': total, 'covered': covered}
                with self.assertRaisesRegex(ValueError, '100%'):
                    self.check([self.entry])

    def test_unrelated_files_do_not_supply_schema_coverage(self):
        unrelated = {'filename': str(self.root / 'test/Tests.swift'), 'summary': {}}
        self.assertIn('100%', self.check([unrelated, self.entry]))

    def test_snapshot_source_is_required_and_must_be_fully_covered(self):
        self.snapshot['summary']['regions']['covered'] = 6
        with self.assertRaisesRegex(ValueError, 'StructuredSnapshotMapper regions'):
            self.check([self.entry])
        self.snapshot['filename'] = str(self.root / 'test/StructuredSnapshotMapper.swift')
        with self.assertRaisesRegex(ValueError, 'production StructuredSnapshotMapper'):
            self.check([self.entry])

    def test_history_codec_is_required_and_must_be_fully_covered(self):
        self.history['summary']['lines']['covered'] = 8
        with self.assertRaisesRegex(ValueError, 'SessionHistoryCodec lines'):
            self.check([self.entry])
        self.history['filename'] = str(self.root / 'test/SessionHistoryCodec.swift')
        with self.assertRaisesRegex(ValueError, 'production SessionHistoryCodec'):
            self.check([self.entry])

    def test_availability_and_language_sources_require_complete_native_coverage(self):
        for entry, name in [(self.monitor, 'AvailabilityMonitor'), (self.languages, 'TextModelLanguageMapper')]:
            with self.subTest(name=name):
                entry['summary']['functions']['covered'] -= 1
                with self.assertRaisesRegex(ValueError, name + ' functions'):
                    self.check([self.entry])
                entry['summary']['functions']['covered'] += 1
                filename = entry['filename']
                entry['filename'] = str(self.root / ('test/' + name + '.swift'))
                with self.assertRaisesRegex(ValueError, 'production ' + name):
                    self.check([self.entry])
                entry['filename'] = filename


if __name__ == '__main__':
    unittest.main()
