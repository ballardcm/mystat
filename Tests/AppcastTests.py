import importlib.util
import pathlib
import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('appcast', ROOT / 'scripts/create-appcast.py')
appcast = importlib.util.module_from_spec(spec)
spec.loader.exec_module(appcast)


class FeedTests(unittest.TestCase):
    def setUp(self):
        self.info = plistlib.loads((ROOT / 'Resources/Info.plist').read_bytes())
        self.info.update(CFBundleShortVersionString='0.2.0', CFBundleVersion='3')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive = pathlib.Path(self.temp.name) / 'MyStat-0.2.0-macos-arm64.zip'
        self.archive.write_bytes(b'fixture archive')

    def test_feed_encodes_version_compatibility_and_notes(self):
        root = ET.fromstring(appcast.create_feed(self.info, self.archive, 'signature', '<script>plain text</script> & notes'))
        item = root.find('channel/item')
        self.assertEqual(item.findtext(f'{{{appcast.SPARKLE}}}version'), '3')
        self.assertEqual(item.findtext(f'{{{appcast.SPARKLE}}}maximumSystemVersion'), '26.99')
        self.assertEqual(item.findtext('description'), '<script>plain text</script> & notes')
        self.assertEqual(item.find('description').attrib[f'{{{appcast.SPARKLE}}}format'], 'plain-text')
        self.assertEqual(item.find('enclosure').attrib['url'], 'https://github.com/ballardcm/mystat/releases/download/v0.2.0/MyStat-0.2.0-macos-arm64.zip')
        self.assertIsNone(item.find(f'{{{appcast.SPARKLE}}}channel'))

    def test_rejects_prereleases_wrong_names_and_insecure_bundles(self):
        for field, value in [('CFBundleShortVersionString', '0.2.0-beta'), ('CFBundleVersion', '3beta'),
                             ('CFBundleShortVersionString', '0.3.0'), ('CFBundleIdentifier', 'other'),
                             ('SUFeedURL', 'https://example.com/feed'), ('SURequireSignedFeed', False),
                             ('SUVerifyUpdateBeforeExtraction', False)]:
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                appcast.create_feed(dict(self.info, **{field: value}), self.archive, 'signature', 'Notes')

    def test_empty_bootstrap_has_no_download(self):
        self.assertIsNone(ET.fromstring(appcast.create_feed()).find('channel/item'))

    def test_security_defaults(self):
        info = plistlib.loads((ROOT / 'Resources/Info.plist').read_bytes())
        for flag in ('SUEnableAutomaticChecks', 'SUAutomaticallyUpdate', 'SUAllowsAutomaticUpdates', 'SUEnableSystemProfiling', 'SUEnableJavaScript'):
            self.assertIs(info[flag], False)
        self.assertEqual(info['SUScheduledCheckInterval'], 86400)
        self.assertEqual(info['SUSignedFeedFailureExpirationInterval'], 0)


if __name__ == '__main__':
    unittest.main()
