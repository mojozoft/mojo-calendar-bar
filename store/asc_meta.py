"""ลงข้อมูลหน้า Store ของ Mojo Calendar Bar (macOS) ผ่าน App Store Connect API แล้วอ่านกลับเทียบ

  python3 store/asc_meta.py            # ดูอย่างเดียว (ไม่แก้อะไร)
  APPLY=1 python3 store/asc_meta.py    # ลงจริง

ข้อความอยู่ใน store/metadata/<locale>/*.txt · review notes ใน store/review/notes-en.txt
ใช้ asc.py (JWT + call) ของ Ginzii iOS — คีย์ API ใบเดียวกัน
"""
import os, sys
sys.path.insert(0, os.path.expanduser('~/Developer/mojozoft/ginzii-com/projects/ginzii-ios/scripts/asc'))
from asc import call  # noqa: E402

APP = '6835091274'
GINZII_APP = '6832027905'  # ก๊อปผู้ติดต่อสำหรับรีวิวจากแอปนี้
# เลขรุ่นมีที่เดียว: MARKETING_VERSION ใน project.yml
import re  # noqa: E402
VERSION = re.search(r'MARKETING_VERSION: "([^"]+)"', open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'project.yml')).read()).group(1)
COPYRIGHT = '2026 Mojozoft'
ROOT = os.path.dirname(os.path.abspath(__file__))
APPLY = os.environ.get('APPLY') == '1'
LOCALES = ['en-US', 'th']


def txt(loc, key):
    return open(f'{ROOT}/metadata/{loc}/{key}.txt').read().rstrip('\n')


def say(*a):
    print(('✏️ ' if APPLY else '👀 ') + ' '.join(str(x) for x in a))


# ── เวอร์ชัน macOS ──
vers = call('GET', f'/v1/apps/{APP}/appStoreVersions?filter[platform]=MAC_OS')['data']
v = vers[0]
VID = v['id']
# กันแก้เวอร์ชันที่ส่งรีวิว/ขายอยู่ (เคยเกือบเปลี่ยนชื่อ 1.0.0 ที่รอรีวิวเป็น 1.1.0) ⇒ ต้องสร้างเวอร์ชันใหม่ใน ASC ก่อน
if v['attributes']['appStoreState'] not in ('PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED'):
    sys.exit(f"เวอร์ชันล่าสุด {v['attributes']['versionString']} อยู่สถานะ {v['attributes']['appStoreState']} แก้ไม่ได้ — สร้างเวอร์ชัน {VERSION} ใน ASC ก่อน")
if v['attributes']['versionString'] != VERSION or v['attributes'].get('copyright') != COPYRIGHT:
    say('version', v['attributes']['versionString'], '→', VERSION, '· copyright', COPYRIGHT)
    if APPLY:
        call('PATCH', f'/v1/appStoreVersions/{VID}', {'data': {'type': 'appStoreVersions', 'id': VID,
             'attributes': {'versionString': VERSION, 'copyright': COPYRIGHT}}})

locs = {x['attributes']['locale']: x for x in call('GET', f'/v1/appStoreVersions/{VID}/appStoreVersionLocalizations')['data']}
for loc in LOCALES:
    a = {'description': txt(loc, 'description'), 'keywords': txt(loc, 'keywords'),
         'promotionalText': txt(loc, 'promotional_text'), 'supportUrl': txt(loc, 'support_url'),
         'marketingUrl': txt(loc, 'marketing_url')}
    if loc in locs:
        say('version loc', loc, 'PATCH')
        if APPLY:
            call('PATCH', f"/v1/appStoreVersionLocalizations/{locs[loc]['id']}", {'data': {
                'type': 'appStoreVersionLocalizations', 'id': locs[loc]['id'], 'attributes': a}})
    else:
        say('version loc', loc, 'CREATE')
        if APPLY:
            call('POST', '/v1/appStoreVersionLocalizations', {'data': {'type': 'appStoreVersionLocalizations',
                 'attributes': {**a, 'locale': loc},
                 'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': VID}}}}})

# ── App info: ชื่อ/คำโปรย/privacy · หมวด · เรตอายุ ──
info = [i for i in call('GET', f'/v1/apps/{APP}/appInfos')['data']
        if i['attributes'].get('appStoreState') != 'READY_FOR_SALE'][0]
IID = info['id']
say('category PRODUCTIVITY / UTILITIES')
if APPLY:
    call('PATCH', f'/v1/appInfos/{IID}', {'data': {'type': 'appInfos', 'id': IID, 'relationships': {
        'primaryCategory': {'data': {'type': 'appCategories', 'id': 'PRODUCTIVITY'}},
        'secondaryCategory': {'data': {'type': 'appCategories', 'id': 'UTILITIES'}}}}})

ilocs = {x['attributes']['locale']: x for x in call('GET', f'/v1/appInfos/{IID}/appInfoLocalizations')['data']}
for loc in LOCALES:
    a = {'name': txt(loc, 'name'), 'subtitle': txt(loc, 'subtitle'), 'privacyPolicyUrl': txt(loc, 'privacy_url')}
    if loc in ilocs:
        say('info loc', loc, 'PATCH')
        if APPLY:
            call('PATCH', f"/v1/appInfoLocalizations/{ilocs[loc]['id']}", {'data': {
                'type': 'appInfoLocalizations', 'id': ilocs[loc]['id'], 'attributes': a}})
    else:
        say('info loc', loc, 'CREATE')
        if APPLY:
            call('POST', '/v1/appInfoLocalizations', {'data': {'type': 'appInfoLocalizations',
                 'attributes': {**a, 'locale': loc},
                 'relationships': {'appInfo': {'data': {'type': 'appInfos', 'id': IID}}}}})

age = call('GET', f'/v1/appInfos/{IID}/ageRatingDeclaration')['data']
enum = ['alcoholTobaccoOrDrugUseOrReferences', 'contests', 'gamblingSimulated', 'gunsOrOtherWeapons',
        'medicalOrTreatmentInformation', 'profanityOrCrudeHumor', 'sexualContentGraphicAndNudity',
        'sexualContentOrNudity', 'horrorOrFearThemes', 'matureOrSuggestiveThemes', 'violenceCartoonOrFantasy',
        'violenceRealisticProlongedGraphicOrSadistic', 'violenceRealistic']
boo = ['advertising', 'ageAssurance', 'gambling', 'healthOrWellnessTopics', 'lootBox', 'messagingAndChat',
       'parentalControls', 'socialMedia', 'socialMediaAgeRestricted', 'unrestrictedWebAccess', 'userGeneratedContent']
say('age rating: NONE ทุกข้อ')
if APPLY:
    attrs = {k: 'NONE' for k in enum}
    attrs.update({k: False for k in boo})
    call('PATCH', f"/v1/ageRatingDeclarations/{age['id']}", {'data': {'type': 'ageRatingDeclarations', 'id': age['id'], 'attributes': attrs}})

# ── ข้อมูลสำหรับผู้ตรวจ ──
notes = open(f'{ROOT}/review/notes-en.txt').read().strip()
rv = call('GET', f'/v1/appStoreVersions/{VID}/appStoreReviewDetail').get('data')
if rv:
    say('review notes PATCH', len(notes), 'ตัวอักษร')
    if APPLY:
        call('PATCH', f"/v1/appStoreReviewDetails/{rv['id']}", {'data': {'type': 'appStoreReviewDetails', 'id': rv['id'],
             'attributes': {'notes': notes, 'demoAccountRequired': False}}})
else:
    src = None
    for gv in call('GET', f'/v1/apps/{GINZII_APP}/appStoreVersions?limit=10')['data']:
        try:
            src = call('GET', f"/v1/appStoreVersions/{gv['id']}/appStoreReviewDetail").get('data')
        except SystemExit:
            src = None
        if src:
            break
    assert src, 'ไม่มีผู้ติดต่อให้ก๊อป'
    a = {k: src['attributes'][k] for k in ['contactFirstName', 'contactLastName', 'contactPhone', 'contactEmail']}
    a.update({'notes': notes, 'demoAccountRequired': False})
    say('review detail CREATE (ผู้ติดต่อจาก Ginzii)')
    if APPLY:
        call('POST', '/v1/appStoreReviewDetails', {'data': {'type': 'appStoreReviewDetails', 'attributes': a,
             'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': VID}}}}})

# ── อ่านกลับเทียบ ──
print('\n── อ่านกลับ ──')
va = call('GET', f'/v1/appStoreVersions/{VID}')['data']['attributes']
print('version', va['versionString'], '·', va.get('copyright'), '·', va['appStoreState'])
for x in call('GET', f'/v1/appStoreVersions/{VID}/appStoreVersionLocalizations')['data']:
    a = x['attributes']
    ok = all(a.get(k) == txt(a['locale'], f) for k, f in [('description', 'description'), ('keywords', 'keywords'),
             ('promotionalText', 'promotional_text'), ('supportUrl', 'support_url')])
    print(' ', a['locale'], 'ตรงไฟล์' if ok else '❌ ไม่ตรง', len(a.get('description') or ''))
for x in call('GET', f'/v1/appInfos/{IID}/appInfoLocalizations')['data']:
    a = x['attributes']
    print(' ', a['locale'], a['name'], '|', a.get('subtitle'), '|', a.get('privacyPolicyUrl'))
b = call('GET', f'/v1/appStoreVersions/{VID}/build').get('data')
print('build ผูกแล้ว' if b else 'build ยังไม่ผูก', b['attributes']['version'] if b else '')
