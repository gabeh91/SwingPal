"""Exercise the real Swift importer as a CLI, including atomic failure behavior."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CatalogImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory()
        cls.binary = Path(cls.build.name) / 'catalog-import'
        subprocess.run(['swiftc', str(ROOT / 'Tools/club_catalog_import.swift'), '-o', str(cls.binary)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.build.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name) / 'source.json'
        self.output = Path(self.temp.name) / 'catalog.json'
        self.document = {
            'schemaVersion': 1,
            'sources': [{'id': 'ping', 'url': 'https://ping.com/en-us/golf-clubs/irons/g440-iron', 'checkedAt': '2026-09-28'}],
            'families': [{'brand': 'PING', 'name': 'G440', 'category': 'iron', 'sourceIDs': ['ping'],
                          'variants': [{'code': '7I', 'displayName': '7I'}, {'code': 'UW', 'displayName': 'UW'}]}]
        }

    def run_import(self, *extra):
        self.source.write_text(json.dumps(self.document))
        return subprocess.run([str(self.binary), '--source', str(self.source), '--output', str(self.output), *extra],
                              capture_output=True, text=True, timeout=20)

    def assert_invalid(self):
        self.output.write_text('existing catalog')
        result = self.run_import()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.output.read_text(), 'existing catalog')

    def test_emits_only_explicit_variants_and_keeps_provenance(self):
        result = self.run_import()
        self.assertEqual(result.returncode, 0, result.stderr)
        out = json.loads(self.output.read_text())
        self.assertEqual(out['brands'], ['PING'])
        self.assertEqual(out['families'], self.document['families'])
        self.assertEqual(out['sources'], self.document['sources'])

    def test_rejects_empty_variants_without_overwriting(self):
        self.document['families'][0]['variants'] = []
        self.assert_invalid()

    def test_rejects_duplicate_variant_codes(self):
        self.document['families'][0]['variants'].append({'code': '7i', 'displayName': 'Another'})
        self.assert_invalid()

    def test_rejects_duplicate_saved_club_names(self):
        self.document['families'][0]['variants'].append({'code': 'OTHER', 'displayName': '7i'})
        self.assert_invalid()

    def test_rejects_duplicate_models(self):
        other = copy.deepcopy(self.document['families'][0])
        other['brand'] = 'ping'
        self.document['families'].append(other)
        self.assert_invalid()

    def test_rejects_saved_identity_collisions_between_categories(self):
        # The bag stores maker/model/displayName, without category in its identity.
        other = copy.deepcopy(self.document['families'][0])
        other['category'] = 'utilityIron'
        self.document['families'].append(other)
        self.assert_invalid()

    def test_rejects_unknown_source(self):
        self.document['families'][0]['sourceIDs'] = ['missing']
        self.assert_invalid()

    def test_rejects_missing_provenance(self):
        self.document['families'][0]['sourceIDs'] = []
        self.assert_invalid()

    def test_rejects_invalid_date_and_url(self):
        for key, value in [('checkedAt', '2026-02-30'), ('url', 'file:///tmp/source')]:
            with self.subTest(key=key):
                original = self.document['sources'][0][key]
                self.document['sources'][0][key] = value
                self.assert_invalid()
                self.document['sources'][0][key] = original

    def test_rejects_unknown_schema(self):
        self.document['schemaVersion'] = 2
        self.assert_invalid()

    def test_check_detects_drift_without_writing(self):
        self.assertEqual(self.run_import().returncode, 0)
        self.assertEqual(self.run_import('--check').returncode, 0)
        self.output.write_text('stale bundle')
        self.assertNotEqual(self.run_import('--check').returncode, 0)
        self.assertEqual(self.output.read_text(), 'stale bundle')

    def test_generation_is_deterministic(self):
        self.assertEqual(self.run_import().returncode, 0)
        first = self.output.read_bytes()
        self.assertEqual(self.run_import().returncode, 0)
        self.assertEqual(self.output.read_bytes(), first)


if __name__ == '__main__':
    unittest.main()
