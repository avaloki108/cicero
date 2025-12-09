import json

with open('/home/dok/Developer/cicero/courtlistener/courts-db-main/courts-db-main/courts_db/data/courts.json') as f:
    courts = json.load(f)

states = {
    'california': 'CA',
    'new york': 'NY', 
    'texas': 'TX',
    'florida': 'FL',
}

for state_name, abbr in states.items():
    print(f'\n=== {abbr} ===')
    ids = []
    for c in courts:
        name = c.get('name', '').lower()
        loc = c.get('location', '').lower()
        cid = c['id']
        if state_name in name or state_name in loc:
            ids.append(cid)
    print(f'"{abbr}": "{",".join(ids)}",')
