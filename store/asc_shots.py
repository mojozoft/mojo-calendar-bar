"""อัปภาพหน้าจอ Mac (APP_DESKTOP) จาก store/screenshots/<locale>/*.png ขึ้นเวอร์ชัน macOS ปัจจุบัน
ข้ามไฟล์ชื่อซ้ำที่มีอยู่แล้ว · จบแล้วพิมพ์สถานะ (UPLOAD_COMPLETE → COMPLETE ใช้ 1–5 นาที)"""
import os, sys, glob, hashlib, subprocess, time
sys.path.insert(0, os.path.expanduser('~/Developer/mojozoft/ginzii-com/projects/ginzii-ios/scripts/asc'))
from asc import call  # noqa: E402

APP = '6835091274'
DT = 'APP_DESKTOP'
S = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'screenshots')
VID = call('GET', f'/v1/apps/{APP}/appStoreVersions?filter[platform]=MAC_OS')['data'][0]['id']
locs = {x['attributes']['locale']: x['id'] for x in call('GET', f'/v1/appStoreVersions/{VID}/appStoreVersionLocalizations')['data']}
for loc, lid in locs.items():
    files = sorted(glob.glob(f'{S}/{loc}/*.png'))
    if not files:
        continue
    sets = call('GET', f'/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets')['data']
    st = [x for x in sets if x['attributes']['screenshotDisplayType'] == DT]
    sid = st[0]['id'] if st else call('POST', '/v1/appScreenshotSets', {'data': {'type': 'appScreenshotSets',
        'attributes': {'screenshotDisplayType': DT},
        'relationships': {'appStoreVersionLocalization': {'data': {'type': 'appStoreVersionLocalizations', 'id': lid}}}}})['data']['id']
    have = {x['attributes']['fileName'] for x in call('GET', f'/v1/appScreenshotSets/{sid}/appScreenshots')['data']}
    for f in files:
        name = os.path.basename(f)
        if name in have:
            print(loc, name, 'มีแล้ว ข้าม'); continue
        data = open(f, 'rb').read()
        r = call('POST', '/v1/appScreenshots', {'data': {'type': 'appScreenshots', 'attributes': {'fileName': name, 'fileSize': len(data)},
                 'relationships': {'appScreenshotSet': {'data': {'type': 'appScreenshotSets', 'id': sid}}}}})['data']
        for op in r['attributes']['uploadOperations']:
            part = data[op['offset']:op['offset'] + op['length']]
            cmd = ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '-X', op['method'], op['url'], '--data-binary', '@-']
            for h in op.get('requestHeaders', []):
                cmd += ['-H', f"{h['name']}: {h['value']}"]
            code = subprocess.run(cmd, input=part, capture_output=True).stdout.decode()
            assert code.startswith('2'), (name, code)
        call('PATCH', f"/v1/appScreenshots/{r['id']}", {'data': {'type': 'appScreenshots', 'id': r['id'],
             'attributes': {'uploaded': True, 'sourceFileChecksum': hashlib.md5(data).hexdigest()}}})
        print(loc, name, 'อัปแล้ว')
time.sleep(10)
for loc, lid in locs.items():
    for s in call('GET', f'/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets')['data']:
        for x in call('GET', f"/v1/appScreenshotSets/{s['id']}/appScreenshots")['data']:
            a = x['attributes']
            print(' ', loc, a['fileName'], a['assetDeliveryState'].get('state'), a['assetDeliveryState'].get('errors') or '')
