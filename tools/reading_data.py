#!/usr/bin/env python3
# The Reading (character creation) for the Godot build: the retired web build's FATE (exported by tools/exp_fate.js to
# fate_raw.json) -> data/reading.json. Animal words renamed (no animals on the Hide), effect lines rebuilt from the numbers
# with each order's own tree names, and the card emblems remapped to the exported faces in art/reading/cards/.
import json, re, sys
SRC = sys.argv[1] if len(sys.argv) > 1 else '/tmp/gd/fate_raw.json'
F = json.load(open(SRC))['FATE']
MAP = json.load(open('/tmp/gd/reading_map.json'))
REN = {  # id -> new name / emblem, and say fixes
    'card': {'moth': ('The Singed Veil', 'flame'), 'lamb': ('The Swaddling', 'heart'), 'crow': ('The Gleaner', 'bowl'), 'ratking': ('The Knot of Mouths', 'mouth')},
    'fear': {'dogs': ('Being hunted', 'shadow'), 'hunger': (None, 'bowl')},
    'sac': {'hunger': (None, 'mouth')},
}
SAYFIX = [
    ('The moth, upside down: it has already burned.', 'The veil upside down: it has already burned.'),
    ('The lamb reversed is the knife.', 'The swaddling reversed is the knife.'),
    ('The crow turned over picks', 'The gleaner turned over picks'),
    ('The rat king reversed hoards', 'The knot reversed hoards'),
    ('Little moth. Little moth.', 'Little wick. Little wick.'),
    ('The wisps come to her like moths. They will come to you. Pray they are only moths.', 'The wisps come to her like sparks to a draught. They will come to you. Pray they are only sparks.'),
    ('The dogs. You can hear them already, can you not', 'Hunted. You can hear it already, can you not'),
]
LAB = {'con': ' Constitution', 'vit': ' Vitality', 'spi': ' Essence', 'stam': ' poise', 'lok': ' life after each kill', 'armor': ' armor',
       'mf': '% magic find', 'hpPct': '% life', 'dmg': '% skill damage', 'fcr': '% faster cast rate', 'gold': '% gold found',
       'res': '% magic resist', 'frw': '% faster movement', 'xp': '% experience', 'regen': '% faster refill'}
TREES = {'animancer': ['Mirror', 'Soul', 'Thread'], 'hemomancer': ['Brood', 'Blood', 'Flesh'], 'ossumancer': ['Ossuary', 'Bone', 'Carapace'],
         'miasmancer': ['Miasma', 'Distortion', 'Death'], 'monk': ['Radiance', 'Absence', 'Destroyer']}
GOD_OF = {'ossumancer': 'tower', 'hemomancer': 'wheel', 'animancer': 'lantern', 'miasmancer': 'hollow', 'monk': 'silence'}
def fxtxt(fx, cls=None):
    parts = []
    for k, v in fx.items():
        if k.startswith('skt'):
            t = TREES.get(cls, ['one', 'another', 'a third'])[int(k[3:])]
            parts.append((0, '+%d to %s skills' % (v, t)))
        elif k in LAB:
            parts.append((0 if v > 0 else 1, ('+' if v > 0 else '') + ('%g' % v) + LAB[k]))
    return ' · '.join(p for _, p in sorted(parts, key=lambda x: x[0]))
def fix(s):
    for a, b in SAYFIX:
        s = s.replace(a, b)
    return s
def emb(rite, iid):
    r = REN.get(rite, {}).get(iid)
    if r and r[1]:
        return r[1]
    return MAP.get(rite, {}).get(iid, 'eye')
def item(rite, x, cls=None):
    o = {'id': x['id'], 'name': x.get('name') or x.get('give') or x.get('ans') or x['id'], 'fx': x.get('fx', {}), 'say': fix(x.get('say', '')), 'emb': emb(rite, x['id'])}
    r = REN.get(rite, {}).get(x['id'])
    if r and r[0]:
        o['name'] = r[0]
    o['txt'] = fxtxt(o['fx'], cls)
    if x.get('rev'):
        o['rev'] = {'fx': x['rev'].get('fx', {}), 'say': fix(x['rev'].get('say', '')), 'txt': fxtxt(x['rev'].get('fx', {}), cls)}
    return o
out = {'caps': {'con': 2, 'vit': 2, 'spi': 2, 'stam': 8, 'lok': 1, 'armor': 6, 'mf': 6, 'hpPct': 5, 'dmg': 4, 'fcr': 5, 'gold': 8, 'res': 5, 'frw': 4, 'xp': 4, 'regen': 6},
       'faces': {}, 'stars': {}}
for cls, g in GOD_OF.items():
    out['faces'][cls] = [item('face', f, cls) for f in F['faces'][g]]
    st = next(s for s in F['stars'] if s['id'] == g)
    out['stars'][cls] = {'name': st['name'], 'sub': st['sub'], 'fx': st['fx'], 'txt': fxtxt(st['fx']), 'say': fix(st['say']), 'emb': emb('star', g)}
# the Mystic's god is the Soul, the Veiled Crone (breath belongs to the Myriad; the old breath lore was dropped)
out['stars']['animancer'].update({'sub': 'the Veiled Crone', 'say': "Yh'Anuul. The Veiled Crone, the god's soul, still at her loom though no hand works it. She drew one thread out of your cradle and held it up to the light. She has not put it down. Little thread. Little thread."})
out['cards'] = [item('card', c) for c in F['cards']]
out['fears'] = [item('fear', c) for c in F['fears']]
out['seeks'] = [item('seek', c) for c in F['seeks']]
out['roads'] = [item('road', c) for c in F['roads']]
out['sacs'] = [item('sac', c) for c in F['sacrifices']]
out['questions'] = [{'q': q['q'], 'a': [item('ans', a) for a in q['a']]} for q in F['questions']]
out['prophecies'] = [fix(p) for p in F['prophecies']]
out['asides'] = {k: [fix(x) for x in v] for k, v in F['asides'].items() if k != 'bones'}
s = json.dumps(out, ensure_ascii=False)
for w in ['moth', 'Moth', 'crow ', 'Crow', 'rat king', 'Rat', 'dogs', 'birds', 'lamb', 'Lamb', 'Weeping Maiden']:
    if w in s:
        print('STILL:', w, s[s.index(w) - 60:s.index(w) + 40])
json.dump(out, open('/tmp/gd/Godmarrow/data/reading.json', 'w'), ensure_ascii=False, indent=1)
print('ok', {k: len(v) for k, v in out.items() if isinstance(v, list)})
