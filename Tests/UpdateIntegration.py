"""Exercise Sparkle's real verifier/downloader/installer using ephemeral test keys and apps."""
import base64
import functools
import http.server
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import threading
import time
import uuid
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE = ROOT / 'build/update-integration'
TOOLS = ROOT / 'build/Sparkle-2.10.0/bin'
SPARKLE = ROOT / 'build/Sparkle-2.10.0/Sparkle.framework'
NS = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', NS)


def run(*args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def make_bundle(path, identifier, build, key, executable):
    contents = path / 'Contents'
    (contents / 'MacOS').mkdir(parents=True)
    (contents / 'Resources').mkdir()
    (contents / 'Frameworks').mkdir()
    shutil.copy2(executable, contents / 'MacOS' / 'Fixture')
    run('ditto', SPARKLE, contents / 'Frameworks/Sparkle.framework')
    info = dict(CFBundleIdentifier=identifier, CFBundleName='MyStat Update Test', CFBundleExecutable='Fixture',
                CFBundlePackageType='APPL', CFBundleVersion=str(build), CFBundleShortVersionString=f'0.1.{build}',
                LSMinimumSystemVersion='26.0', LSUIElement=True, NSPrincipalClass='NSApplication',
                SUFeedURL='http://127.0.0.1/feed.xml', SUPublicEDKey=key, SUEnableAutomaticChecks=False,
                SUAutomaticallyUpdate=False, SUAllowsAutomaticUpdates=False, SUEnableSystemProfiling=False,
                SURequireSignedFeed=True, SUVerifyUpdateBeforeExtraction=True, SUSignedFeedFailureExpirationInterval=0,
                NSAppTransportSecurity={'NSAllowsLocalNetworking': True, 'NSAllowsArbitraryLoads': True})
    (contents / 'Info.plist').write_bytes(plistlib.dumps(info))
    run('codesign', '--force', '--sign', '-', path, capture_output=True)


def main():
    # Private fixture keys never leave this ignored temporary directory and are removed afterwards.
    with tempfile.TemporaryDirectory(prefix='run-', dir=BASE) as tmp:
        root = pathlib.Path(tmp)
        keyfile = root / 'fixture.key'
        public = subprocess.check_output([str(BASE / 'Fixture'), str(keyfile)], text=True).strip()
        keyfile.chmod(0o600)
        identifier = 'io.github.ballardcm.MyStat.UpdateTest.' + uuid.uuid4().hex
        harness = root / 'Harness.app'
        make_bundle(harness, identifier + '.harness', 1, public, BASE / 'Harness')
        target = root / 'Target.app'
        make_bundle(target, identifier, 1, public, BASE / 'Fixture')
        staged = root / 'stage'
        staged.mkdir()
        make_bundle(staged / 'Target.app', identifier, 2, public, BASE / 'Fixture')
        webroot = root / 'www'
        webroot.mkdir()
        archive = webroot / 'update.zip'
        run('ditto', '-c', '-k', '--keepParent', staged / 'Target.app', archive)
        signature = subprocess.check_output([str(TOOLS / 'sign_update'), '--ed-key-file', str(keyfile), '-p', str(archive)], text=True).strip()

        class Handler(http.server.SimpleHTTPRequestHandler):
            requests = 0
            def do_GET(self):
                Handler.requests += 1
                super().do_GET()
            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=webroot))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        origin = f'http://127.0.0.1:{server.server_port}'

        def feed(name, build=2, channel=None, min_os='26.0', bad_signature=False, missing=False):
            rss = ET.Element('rss', version='2.0')
            ch = ET.SubElement(rss, 'channel')
            ET.SubElement(ch, 'title').text = 'Integration test'
            item = ET.SubElement(ch, 'item')
            ET.SubElement(item, f'{{{NS}}}version').text = str(build)
            ET.SubElement(item, f'{{{NS}}}shortVersionString').text = f'0.1.{build}'
            ET.SubElement(item, f'{{{NS}}}minimumSystemVersion').text = min_os
            if channel:
                ET.SubElement(item, f'{{{NS}}}channel').text = channel
            ET.SubElement(item, 'description', {f'{{{NS}}}format': 'plain-text'}).text = 'Test release notes'
            ET.SubElement(item, 'enclosure', {'url': origin + ('/missing.zip' if missing else '/update.zip'),
                'length': str(archive.stat().st_size), 'type': 'application/octet-stream',
                f'{{{NS}}}edSignature': base64.b64encode(bytes(64)).decode() if bad_signature else signature})
            path = webroot / name
            path.write_bytes(ET.tostring(rss, encoding='utf-8', xml_declaration=True))
            run(TOOLS / 'sign_update', '--ed-key-file', keyfile, path, capture_output=True)
            return path

        def check(name, expected, checked_target=target):
            run(harness / 'Contents/MacOS/Fixture', checked_target, origin + '/' + name, expected, timeout=55)
            info = plistlib.loads((checked_target / 'Contents/Info.plist').read_bytes())
            assert info['CFBundleVersion'] == ('2' if expected == 'installed' else '1'), name
            assert (checked_target / 'Contents/MacOS/Fixture').exists(), name
            if checked_target != target:
                marker = checked_target.parent / 'launched-1'
                process = subprocess.Popen([str(checked_target / 'Contents/MacOS/Fixture')])
                try:
                    for _ in range(100):
                        if marker.exists() or process.poll() is not None:
                            break
                        time.sleep(0.1)
                    assert process.poll() is None, f'{name}: original app exited after rejected update'
                    assert marker.read_text() == '5', f'{name}: original app did not launch normally'
                finally:
                    if process.poll() is None:
                        process.terminate()
                    process.wait(timeout=5)

        # Installer shutdown can outlive the updater cycle. Give installation and
        # download failures distinct host identities so a lingering installer
        # cannot divert a later scenario into Sparkle's resume path.
        isolated_identifiers = []

        def isolated_target(name):
            scenario_identifier = identifier + '.' + name
            isolated_identifiers.append(scenario_identifier)
            bundle = root / name / 'Target.app'
            make_bundle(bundle, scenario_identifier, 1, public, BASE / 'Fixture')
            return bundle

        target_process = None
        try:
            feed('same.xml', build=1)
            before = Handler.requests
            check('same.xml', 'disabled')
            assert Handler.requests == before, 'Default-off updater sent a request'
            check('same.xml', 'background')
            assert Handler.requests > before, 'Opt-in did not schedule a check'
            before = Handler.requests
            check('same.xml', 'disabled')
            assert Handler.requests == before, 'Opt-out did not persist across relaunch'
            check('same.xml', 'no-update')
            feed('older.xml', build=0); check('older.xml', 'no-update')
            feed('beta.xml', channel='beta'); check('beta.xml', 'no-update')
            feed('unsupported.xml', min_os='99.0'); check('unsupported.xml', 'no-update')
            feed('defer.xml'); check('defer.xml', 'defer')
            feed('cancel.xml'); check('cancel.xml', 'cancel')
            path = feed('tampered.xml'); path.write_bytes(path.read_bytes().replace(b'Test release notes', b'Fake release notes'))
            check('tampered.xml', 'error')
            feed('bad-archive.xml', bad_signature=True)
            check('bad-archive.xml', 'error', isolated_target('BadArchiveTarget'))
            feed('missing.xml', missing=True)
            check('missing.xml', 'error', isolated_target('MissingDownloadTarget'))
            check('nonexistent.xml', 'error')
            target_process = subprocess.Popen([str(target / 'Contents/MacOS/Fixture')])
            for _ in range(100):
                if (root / 'launched-1').exists():
                    break
                time.sleep(0.1)
            assert (root / 'launched-1').read_text() == '5'
            feed('install.xml'); check('install.xml', 'installed')
            for _ in range(100):
                if (root / 'launched-2').exists():
                    break
                time.sleep(0.1)
            assert (root / 'launched-2').read_text() == '5', 'Relaunch/preferences not preserved'
            print('PASS: signed feeds, archive rejection, selection, defer/cancel, download failures, install/relaunch and preserved preferences.')
        finally:
            server.shutdown()
            if target_process:
                target_process.terminate()
                target_process.wait(timeout=5)
            # Only terminate our uniquely identified fixture app, including a relaunched instance.
            subprocess.run(['/usr/bin/pkill', '-f', str(target / 'Contents/MacOS/Fixture')], check=False)
            subprocess.run(['/usr/bin/defaults', 'delete', identifier], capture_output=True)
            subprocess.run(['/usr/bin/defaults', 'delete', identifier + '.harness'], capture_output=True)
            for scenario_identifier in isolated_identifiers:
                subprocess.run(['/usr/bin/defaults', 'delete', scenario_identifier], capture_output=True)


if __name__ == '__main__':
    main()
