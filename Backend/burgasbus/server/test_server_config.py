import ast
import json
import unittest
from pathlib import Path
from build_cloud_init import config
from check_configuration import validate

ROOT = Path(__file__).resolve().parent


class ServerConfigTests(unittest.TestCase):
    def test_generated_file_contains_current_sources_and_does_not_start_importer(self):
        document = (ROOT / 'cloud-init.yaml').read_text()
        self.assertTrue(document.startswith('#cloud-config\n'))
        parsed = json.loads(document.split('\n', 1)[1])
        self.assertEqual(parsed, config())
        entries = {entry['path']: entry for entry in parsed['write_files']}
        self.assertEqual(entries['/opt/burgasbus/import_feed.py']['content'], (ROOT.parent / 'import_feed.py').read_text())
        for path, entry in entries.items():
            if path.endswith('.py'):
                ast.parse(entry['content'])
        self.assertNotIn('/etc/burgasbus/feeds.env', entries)
        self.assertIn('systemctl disable burgasbus-importer.service', entries['/opt/burgasbus/install.sh']['content'])
        self.assertNotIn('enable --now', entries['/opt/burgasbus/install.sh']['content'])
        self.assertNotIn('AF_INET6', entries['/etc/systemd/system/burgasbus-importer.service']['content'])

    def test_blank_example_cannot_start_importing(self):
        with self.assertRaises(ValueError):
            validate({})
        with self.assertRaises(ValueError):
            validate({'BURGASBUS_GTFS_URL': 'https://example.invalid/static',
                      'BURGASBUS_VEHICLES_URL': 'https://example.invalid/live',
                      'SUPABASE_URL': 'https://example.invalid',
                      'SUPABASE_SERVICE_ROLE_KEY': 'sb_publishable_fixture'})

    def test_urls_and_headers_validated_without_echoing_secrets(self):
        env = dict(BURGASBUS_GTFS_URL='https://example.invalid/static',
                   BURGASBUS_VEHICLES_URL='https://example.invalid/live',
                   SUPABASE_URL='https://example.invalid', SUPABASE_SERVICE_ROLE_KEY='test-only-value')
        validate(env)
        for headers in ('[]', '{"Authorization": 5}', '{"Authorization": "bad\\nheader"}'):
            with self.assertRaises(ValueError):
                validate(dict(env, BURGASBUS_HEADERS_JSON=headers))
        with self.assertRaises(ValueError):
            validate(dict(env, SUPABASE_URL='https://example.invalid/wrong/path'))


if __name__ == '__main__':
    unittest.main()
