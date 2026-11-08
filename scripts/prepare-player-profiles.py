#!/usr/bin/env python3
"""Build a compact bundled profile resource from the supplied CSV."""
import csv, datetime, json, re
from pathlib import Path
root = Path(__file__).resolve().parent.parent
mapping = {'Goalkeeper':'GK','Right-Back':'DR','Left-Back':'DL','Centre-Back':'DC','Sweeper':'DC','Central Midfield':'MC','Defensive Midfield':'MB','Attacking Midfield':'MA','Left Midfield':'ML','Right Midfield':'MC','Right Winger':'AR','Left Winger':'AL','Centre-Forward':'AC','Second Striker':'AC'}
fallback = {'Goalkeeper':'GK','Defender':'DC','Midfield':'MC','Attack':'AC'}
profiles=[]
seen=set()
with (root/'db/player_profiles.csv').open(encoding='utf-8-sig',newline='') as f:
    for row in csv.DictReader(f):
        name=re.sub(r'\s*\(\d+\)$','',row['player_name']).strip()
        club=row['current_club_name'].strip()
        if not name or not club or club.lower() in {'retired','without club','unknown','---','career break','n/a','not applicable'} or row['date_of_death'].strip(): continue
        try: dob=datetime.date.fromisoformat(row['date_of_birth'])
        except ValueError: continue
        if dob > datetime.date.today(): continue
        position=mapping.get(row['position'].split(' - ')[-1],fallback.get(row['main_position']))
        if not position: continue
        parts=name.split(' ',1)
        first=parts[0]; last=parts[1] if len(parts)>1 else ''
        if len(first)>120 or len(last)>120: continue
        key=(name,dob.isoformat(),club)
        if key in seen: continue
        seen.add(key)
        profiles.append(dict(first=first,last=last,dob=dob.strftime('%Y%m%d'),club=club,clubID=row["current_club_id"],position=position,foot=row['foot'].lower(),image=row['player_image_url'].strip() or None))
# Select the latest team record and match country names to the supplied catalog.
countries=json.loads((root/'db/countries.json').read_text())
by_name={c['name'].casefold():c['iso3'] for c in countries}
aliases={'england':'GBR','scotland':'GBR','wales':'GBR','northern ireland':'GBR','united states':'USA','korea, south':'KOR','south korea':'KOR','russia':'RUS','iran':'IRN','czech republic':'CZE','türkiye':'TUR','turkey':'TUR','vietnam':'VNM','ivory coast':'CIV'}
latest={}
with (root/'db/team_details.csv').open(encoding='utf-8-sig',newline='') as f:
    for row in csv.DictReader(f):
        old=latest.get(row['club_id'])
        if old is None or (row['season_id'],row['_last_modified_at']) > (old['season_id'],old['_last_modified_at']): latest[row['club_id']]=row
teams=[]
for club_id,row in latest.items():
    code=by_name.get(row['country_name'].casefold()) or aliases.get(row['country_name'].casefold())
    name=re.sub(r'\s*\(\d+\)$','',row['club_name']).strip()
    if not code or not name or len(name)>120: continue
    teams.append(dict(id=club_id,name=name,country=code,league=row['competition_name'].strip()[:120],logo=row['logo_url'].strip() or None))
by_id={t['id']:t for t in teams}
for profile in profiles:
    if profile['clubID'] in by_id: profile['club']=by_id[profile['clubID']]['name']
(root/'db/team_details.json').write_text(json.dumps(teams,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
print(f'Prepared {len(teams)} teams with matched countries')
(root/'db/player_profiles.json').write_text(json.dumps(profiles,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
print(f'Prepared {len(profiles)} player profiles')
