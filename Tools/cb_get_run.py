import re, json
from pathlib import Path
import requests

conf = Path('Configuration/Codebeamer/Codebeamer_Configuration.resource')
text = conf.read_text(encoding='utf-8-sig')
pat = re.compile(r"\$\{(cbUserName|cbPwd)\}\s+(.+)$", re.M)
vals = {k: v.strip() for k, v in pat.findall(text)}
user = vals.get('cbUserName')
pwd = vals.get('cbPwd')
print('Using credentials from Configuration/Codebeamer/Codebeamer_Configuration.resource ->', user)
# Try to GET the test run details
test_run_id = '148585'
base = 'https://crdn.codebeamer.com'
endpoints = [f'/rest/v3/testruns/{test_run_id}', f'/rest/v3/items/{test_run_id}', f'/rest/v3/trackers/261965/testruns/{test_run_id}']
for e in endpoints:
    url = base + e
    try:
        r = requests.get(url, auth=(user, pwd), timeout=20)
        print('\nGET', url, '->', r.status_code)
        try:
            j = r.json()
            print(json.dumps(j, indent=2)[:8000])
        except Exception as ex:
            print('No JSON body or failed to parse:', ex)
            print('Text body (truncated):', r.text[:2000])
    except Exception as ex:
        print('Request to', url, 'failed:', ex)
