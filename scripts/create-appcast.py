#!/usr/bin/env python3
"""Create and sign the stable feed. No upload or release publishing is performed."""
import argparse
import pathlib
import plistlib
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
FEED_URL = 'https://raw.githubusercontent.com/ballardcm/mystat/main/docs/appcast.xml'
RELEASES = 'https://github.com/ballardcm/mystat/releases'
ACCOUNT = 'io.github.ballardcm.MyStat'
ET.register_namespace('sparkle', SPARKLE)


def create_feed(info=None, archive=None, signature=None, notes=None):
    root = ET.Element('rss', version='2.0')
    channel = ET.SubElement(root, 'channel')
    ET.SubElement(channel, 'title').text = 'MyStat stable updates'
    ET.SubElement(channel, 'link').text = RELEASES
    ET.SubElement(channel, 'description').text = 'Stable releases for Apple Silicon on macOS 26 and 27.'
    if info is not None:
        version, build = info['CFBundleShortVersionString'], info['CFBundleVersion']
        if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version) or not re.fullmatch(r'[0-9]+', build):
            raise ValueError('Stable numeric version and integer build number required; prereleases are not accepted.')
        if archive.name != f'MyStat-{version}-macos-arm64.zip':
            raise ValueError('Archive filename must match its bundle version.')
        if info['CFBundleIdentifier'] != ACCOUNT or info.get('SUFeedURL') != FEED_URL:
            raise ValueError('Archive must contain MyStat with the official update feed.')
        for flag in ('SURequireSignedFeed', 'SUVerifyUpdateBeforeExtraction'):
            if info.get(flag) is not True:
                raise ValueError(f'{flag} must be enabled.')
        if not notes or not notes.strip():
            raise ValueError('Plain-text release notes are required.')
        item = ET.SubElement(channel, 'item')
        ET.SubElement(item, 'title').text = f'MyStat {version}'
        ET.SubElement(item, f'{{{SPARKLE}}}version').text = build
        ET.SubElement(item, f'{{{SPARKLE}}}shortVersionString').text = version
        ET.SubElement(item, f'{{{SPARKLE}}}minimumSystemVersion').text = '26.0'
        ET.SubElement(item, f'{{{SPARKLE}}}maximumSystemVersion').text = '27.99'
        ET.SubElement(item, 'description', {f'{{{SPARKLE}}}format': 'plain-text'}).text = notes
        ET.SubElement(item, 'enclosure', {
            'url': f'{RELEASES}/download/v{version}/{archive.name}',
            'length': str(archive.stat().st_size), 'type': 'application/octet-stream',
            f'{{{SPARKLE}}}edSignature': signature,
            f'{{{SPARKLE}}}installationType': 'application',
            f'{{{SPARKLE}}}os': 'macos',
        })
    ET.indent(root)
    return ET.tostring(root, encoding='utf-8', xml_declaration=True) + b'\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=pathlib.Path)
    parser.add_argument('--notes', type=pathlib.Path, help='Plain-text release notes')
    parser.add_argument('--empty', action='store_true', help='Bootstrap a signed feed with no updates')
    parser.add_argument('--output', required=True, type=pathlib.Path)
    args = parser.parse_args()
    if args.empty == bool(args.archive) or (args.archive and not args.notes):
        parser.error('Use --empty OR --archive ZIP --notes TEXT')
    # The shell script checks the pinned dependency before using its signing tools.
    subprocess.run(['zsh', '-c', 'set -euo pipefail; source scripts/sparkle.sh'], cwd=ROOT, check=True)
    tools = ROOT / 'build/Sparkle-2.10.0/bin'
    public_key = subprocess.check_output([str(tools / 'generate_keys'), '--account', ACCOUNT, '-p'], text=True).strip()
    source_info = plistlib.loads((ROOT / 'Resources/Info.plist').read_bytes())
    if public_key != source_info['SUPublicEDKey']:
        raise ValueError('The Keychain signing key does not match the pinned public key.')
    info, signature, notes = None, None, None
    if args.archive:
        with zipfile.ZipFile(args.archive) as archive:
            info = plistlib.loads(archive.read('MyStat.app/Contents/Info.plist'))
        if info.get('SUPublicEDKey') != public_key:
            raise ValueError('Archive public key does not match the signing key.')
        signature = subprocess.check_output([str(tools / 'sign_update'), '--account', ACCOUNT, '-p', str(args.archive)], text=True).strip()
        notes = args.notes.read_text()
    data = create_feed(info, args.archive, signature, notes)
    # Publishing is a separate, reviewed PR. Never write directly to the production feed.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(data)
    subprocess.run([str(tools / 'sign_update'), '--account', ACCOUNT, str(args.output)], check=True)
    subprocess.run([str(tools / 'sign_update'), '--account', ACCOUNT, '--verify', str(args.output)], check=True)
    print(f'Signed feed: {args.output}. Publish the stable release first, then update docs/appcast.xml via PR.')


if __name__ == '__main__':
    main()
