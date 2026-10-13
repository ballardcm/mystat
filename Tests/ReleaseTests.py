"""Exercise release failure gates with disposable command fixtures, without keys/network."""
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
MOCK = '''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['RELEASE_TEST_LOG'], 'a') as log:
    log.write(json.dumps([name] + args) + '\\n')
if os.environ.get('RELEASE_TEST_FAIL') == name + ' ' + ' '.join(args[:2]):
    sys.exit(1)
if name == 'xcrun' and args[:2] == ['notarytool', 'submit']:
    print(json.dumps({'id': 'fixture-id', 'status': os.environ.get('RELEASE_TEST_STATUS', 'Accepted')}))
if name == 'ditto' and '-c' in args:
    pathlib.Path(args[-1]).write_bytes(b'fixture archive')
'''


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        for folder in ('scripts', 'bin', 'build/MyStat.app/Contents', 'Resources',
                       'docs/screenshots', 'ThirdParty'):
            (self.root / folder).mkdir(parents=True, exist_ok=True)
        for script in ('release.sh', 'sign-app.sh'):
            shutil.copy(ROOT / 'scripts' / script, self.root / 'scripts' / script)
        for command in ('codesign', 'xcrun', 'spctl', 'ditto', 'test.sh', 'build.sh'):
            target = self.root / ('scripts' if command.endswith('.sh') else 'bin') / command
            target.write_text(MOCK)
            target.chmod(0o755)
        for target in ('Resources/Info.plist', 'build/MyStat.app/Contents/Info.plist'):
            shutil.copy(ROOT / 'Resources/Info.plist', self.root / target)
        for target in ('LICENSE', 'THIRD_PARTY_NOTICES.md', 'INSTALL.md', 'README.md',
                       'CONTRIBUTING.md', 'ThirdParty/Sparkle-LICENSE.txt', 'docs/UPDATES.md',
                       'docs/RELEASE_TESTING.md', 'docs/SIGNING.md', 'docs/screenshots/test.png'):
            (self.root / target).touch()
        self.log = self.root / 'commands.jsonl'
        self.env = dict(os.environ, PATH=f"{self.root / 'bin'}:{os.environ['PATH']}",
                        RELEASE_TEST_LOG=str(self.log), MYSTAT_SIGN_IDENTITY='fixture identity',
                        MYSTAT_NOTARY_PROFILE='fixture profile')

    def run_script(self, name='release.sh', *args):
        return subprocess.run(['/bin/zsh', str(self.root / 'scripts' / name), *args],
                              env=self.env, capture_output=True, text=True)

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_missing_identity_fails_before_build(self):
        del self.env['MYSTAT_SIGN_IDENTITY']
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertFalse(self.log.exists())

    def test_rejected_notarization_never_staples_or_packages(self):
        self.env['RELEASE_TEST_STATUS'] = 'Invalid'
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertFalse((self.root / 'dist').exists())
        self.assertFalse(any(c[:2] == ['xcrun', 'stapler'] for c in self.commands()))

    def test_verification_failures_never_package(self):
        for failure in ('xcrun notarytool submit', 'xcrun stapler staple',
                        'xcrun stapler validate', 'spctl --assess --type'):
            with self.subTest(failure=failure):
                self.env['RELEASE_TEST_FAIL'] = failure
                self.assertNotEqual(self.run_script().returncode, 0)
                self.assertFalse((self.root / 'dist').exists())

    def test_accepted_submission_is_stapled_and_assessed_before_final_zip(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        staple = next(i for i, c in enumerate(commands) if c[:3] == ['xcrun', 'stapler', 'staple'])
        assess = next(i for i, c in enumerate(commands) if c[0] == 'spctl')
        archive = next(i for i, c in enumerate(commands) if c[0] == 'ditto' and c[-1].endswith('macos-arm64.zip'))
        self.assertLess(staple, assess)
        self.assertLess(assess, archive)
        self.assertTrue((self.root / 'dist/SHA256SUMS').is_file())

    def test_resume_rechecks_ticket_without_build_or_submission(self):
        self.env['RELEASE_TEST_FAIL'] = 'xcrun stapler validate'
        self.assertNotEqual(self.run_script('release.sh', '--package-notarized').returncode, 0)
        self.assertFalse((self.root / 'dist').exists())
        self.assertFalse(any(c[0] in ('build.sh', 'test.sh') or c[:2] == ['xcrun', 'notarytool']
                             for c in self.commands()))

    def test_adhoc_is_isolated_and_does_not_submit(self):
        result = self.run_script('release.sh', '--adhoc')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / 'dist/adhoc/SHA256SUMS').is_file())
        self.assertFalse((self.root / 'dist/SHA256SUMS').exists())
        self.assertFalse(any(c[0] in ('xcrun', 'spctl') for c in self.commands()))

    def test_nested_distribution_code_gets_runtime_and_timestamp(self):
        result = self.run_script('sign-app.sh', 'MyStat.app')
        self.assertEqual(result.returncode, 0, result.stderr)
        signed = [c for c in self.commands() if '--sign' in c]
        self.assertEqual([pathlib.Path(c[-1]).name for c in signed],
                         ['Autoupdate', 'Updater.app', 'Sparkle.framework', 'MyStat.app'])
        for command in signed:
            self.assertIn('--timestamp', command)
            self.assertIn('runtime', command)
            self.assertNotIn('--deep', command)


if __name__ == '__main__':
    unittest.main()
