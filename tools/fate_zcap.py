#!/usr/bin/env python3
"""The Reading's numbers reined in, as the browser's zz_fate_zcap.js (v0.53) does at run time:
every percent bonus or cost from any single choice is +1 or -1; flat values are held to small steps
(attributes 2, armor and poise 4, life per kill 1); skill bonuses (skt*) untouched. The texts are rebuilt
to match. data/reading.json was exported from the source tables before that patch, so the user's rule
("at most it should be 1%", 2026-09-28) was not in effect in Godot. Run from the project root; safe to repeat.
"""
import json, re

PCT = ['dmg', 'frw', 'fcr', 'res', 'mf', 'regen', 'hpPct', 'xp', 'gold']
FLAT = {'vit': 2, 'spi': 2, 'con': 2, 'armor': 4, 'stam': 4, 'lok': 1}
NUM = re.compile(r'^([+-]?)(\d+(?:\.\d+)?)(%?)')


def clamp(fx):
    out = {}
    for k, v in fx.items():
        if not v or k.startswith('skt'):
            out[k] = v
            continue
        c = 1 if k in PCT else FLAT.get(k)
        out[k] = (1 if v > 0 else -1) * min(abs(v), c) if c else v
    return out


def rebuild_txt(txt, old_fx, new_fx):
    parts = [t.strip() for t in txt.split('·')] if txt else []
    keys = [k for k, v in old_fx.items() if v]
    if len(parts) != len(keys):
        return txt
    out = []
    for k, part in zip(keys, parts):
        v = new_fx[k]
        m = NUM.match(part)
        if m and v != old_fx[k]:
            num = f"{v:+g}" if isinstance(v, (int, float)) else str(v)
            part = num + m.group(3) + part[m.end():]
        out.append(part)
    return ' · '.join(out)


def fix(e, stats):
    if not isinstance(e, dict) or 'fx' not in e:
        return
    new = clamp(e['fx'])
    if new != e['fx']:
        stats[0] += 1
        e['txt'] = rebuild_txt(e.get('txt', ''), e['fx'], new)
        e['fx'] = new
    if isinstance(e.get('rev'), dict):
        fix(e['rev'], stats)


def walk(o, stats):
    if isinstance(o, dict):
        fix(o, stats)
        for v in o.values():
            walk(v, stats)
    elif isinstance(o, list):
        for v in o:
            walk(v, stats)


if __name__ == '__main__':
    path = 'data/reading.json'
    d = json.load(open(path))
    stats = [0]
    walk(d, stats)
    # the sum caps stay as a second guard, but the per-choice clamp is now the rule
    d.setdefault('notes', []).append('fx clamped per choice by tools/fate_zcap.py (browser zz_fate_zcap.js): percents +-1, vit/spi/con 2, armor/stam 4, lok 1')
    json.dump(d, open(path, 'w'), ensure_ascii=False, separators=(',', ':'))
    print(f'{stats[0]} choices clamped')
