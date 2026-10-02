import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_coverage


class CoverageGateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        (self.root / 'lib').mkdir()
        (self.root / 'lib/model.dart').write_text('int answer() => 42;\n')
        self.report = self.root / 'lcov.info'

    def record(self, source='lib/model.dart', hits=1, found=1, hit=1):
        return f'SF:{source}\nDA:1,{hits}\nLF:{found}\nLH:{hit}\nend_of_record\n'

    def check(self, report):
        self.report.write_text(report)
        return check_coverage.check(self.report, self.root)

    def test_complete_report_passes(self):
        self.assertIn('1/1 (100%)', self.check(self.record()))

    def test_export_barrel_and_abstract_signatures_have_no_executable_lines(self):
        (self.root / 'lib/package.dart').write_text("export 'model.dart';\n")
        (self.root / 'lib/platform.dart').write_text('abstract interface class Platform { Future<int> count({required String text}); }')
        self.assertIn('100%', self.check(self.record()))

    def test_new_executable_file_cannot_disappear_from_the_report(self):
        (self.root / 'lib/new.dart').write_text('int uncovered() => 0;')
        with self.assertRaisesRegex(ValueError, 'Missing executable'):
            self.check(self.record())

    def test_method_body_in_interface_is_executable(self):
        (self.root / 'lib/platform.dart').write_text('abstract interface class Platform { int count() => 1; }')
        with self.assertRaisesRegex(ValueError, 'Missing executable'):
            self.check(self.record())

    def test_one_uncovered_line_fails(self):
        with self.assertRaisesRegex(ValueError, 'exactly 100%'):
            self.check(self.record(hits=0, hit=0))

    def test_missing_report_fails(self):
        with self.assertRaises(FileNotFoundError):
            check_coverage.check(self.report, self.root)

    def test_empty_report_fails(self):
        with self.assertRaisesRegex(ValueError, 'Missing executable'):
            self.check('')

    def test_counter_mismatch_fails(self):
        with self.assertRaisesRegex(ValueError, 'counters disagree'):
            self.check(self.record(found=2))

    def test_duplicate_record_fails(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            self.check(self.record() * 2)

    def test_sources_outside_lib_fail(self):
        with self.assertRaisesRegex(ValueError, 'Unexpected'):
            self.check(self.record(source='../outside.dart'))

    def test_invalid_line_counts_fail(self):
        with self.assertRaisesRegex(ValueError, 'Invalid line'):
            self.check(self.record(hits=-1))

    def test_missing_source_field_fails(self):
        with self.assertRaisesRegex(ValueError, 'exactly one source'):
            self.check('DA:1,1\nLF:1\nLH:1\nend_of_record\n')


if __name__ == '__main__':
    unittest.main()
