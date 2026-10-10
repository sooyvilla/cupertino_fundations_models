import json
import sys
import tempfile
import unittest
from pathlib import Path

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

    def check(self, entries):
        self.report.write_text(json.dumps({'data': [{'files': entries + [self.snapshot, self.history, self.monitor, self.languages]}]}))
        return check_schema_coverage.check(self.report, self.root)

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
