"""
`flutter create` ke baad ek baar chalayein (app folder ke andar):
    python3 patch_manifest.py
Ye AndroidManifest.xml me permissions, http support aur app ka naam "EstateSathi" set kar deta hai.
"""
import pathlib
import re
import sys

p = pathlib.Path('android/app/src/main/AndroidManifest.xml')
if not p.exists():
    sys.exit('AndroidManifest.xml nahi mila. Pehle "flutter create ." chalayein aur app folder ke andar se ye script chalayein.')

s = p.read_text(encoding='utf-8')
if 'android.permission.SEND_SMS' in s:
    sys.exit('Manifest pehle se patched hai.')

perms = '''
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.SEND_SMS"/>
    <uses-permission android:name="android.permission.READ_PHONE_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="sms"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="tel"/>
        </intent>
    </queries>'''

s = re.sub(r'(<manifest[^>]*>)', lambda m: m.group(1) + perms, s, count=1)
s = s.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="EstateSathi"', s, count=1)
p.write_text(s, encoding='utf-8')
print('Manifest patch ho gaya.')
