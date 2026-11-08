#!/usr/bin/env python3
"""Populate the template country table from countries.csv without replacing IDs."""
import json
import csv
import ctypes
import sqlite3
from pathlib import Path

root = Path(__file__).resolve().parent.parent
icu = ctypes.CDLL('/usr/lib/libicucore.A.dylib')
iso3 = icu.uloc_getISO3Country
iso3.argtypes = [ctypes.c_char_p]
iso3.restype = ctypes.c_char_p
with (root / 'db/countries.csv').open(encoding='utf-8-sig', newline='') as source:
    countries = list(csv.DictReader(source))
prepared = []
for country in countries:
    name, code = country['Name'].strip(), country['Code'].strip().upper()
    converted = iso3(('en_' + code).encode()).decode()
    if not name or len(code) != 2 or len(converted) != 3:
        raise ValueError(f'Invalid country: {country}')
    prepared.append((name, code, converted))
if len({row[1] for row in prepared}) != len(prepared):
    raise ValueError('Duplicate country codes')
with sqlite3.connect(root / 'db/db.sqlite') as db:
    db.execute('PRAGMA foreign_keys=ON')
    columns = {row[1] for row in db.execute('PRAGMA table_info(country)')}
    column = 'country_iso3' if 'country_iso3' in columns else 'country_iso2'
    for name, alpha2, alpha3 in prepared:
        code = alpha3 if column == 'country_iso3' else alpha2
        match = db.execute(f'SELECT id FROM country WHERE {column}=?', (code,)).fetchone()
        if match:
            db.execute('UPDATE country SET country_name=? WHERE id=?', (name, match[0]))
        else:
            match = db.execute('SELECT id FROM country WHERE country_name=?', (name,)).fetchone()
            if match:
                db.execute(f'UPDATE country SET {column}=? WHERE id=?', (code, match[0]))
            else:
                db.execute(f'INSERT INTO country (country_name,{column}) VALUES (?,?)', (name, code))
    if db.execute('PRAGMA foreign_key_check').fetchall():
        raise ValueError('Database contains invalid relationships')
    if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
        raise ValueError('Database integrity check failed')
    print(f'Imported {len(prepared)} countries; country table contains {db.execute("SELECT count(*) FROM country").fetchone()[0]} records.')

(root / "db/countries.json").write_text(json.dumps([dict(name=n, iso2=a, iso3=b) for n,a,b in prepared], ensure_ascii=False), encoding="utf-8")
