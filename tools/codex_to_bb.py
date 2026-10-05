#!/usr/bin/env python3
# The Codex of the Hide for the Godot build: /home/claude/lore/codex.json (HTML, made by lore/gen.py) -> data/codex.json
# (BBCode pages for ui/codex.gd). Run after any change to the lore sources.
import json, re, html, sys
SRC = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/lore/codex.json'
book = json.load(open(SRC))
ORN = '\n[center][color=#8c6a37]❧[/color][/center]\n'
def bb(h):
    h = h.replace('\n', '')
    h = re.sub(r'<p class="orn">.*?</p>', ORN, h)
    h = re.sub(r'<div class="carve">(.*?)<span class="under">(.*?)</span></div>', lambda m: '\n[center][font_size=26][color=#dcd3c2]' + m.group(1).replace('<br>', '\n') + '[/color][/font_size]\n[i][color=#6f685f]' + m.group(2) + '[/color][/i][/center]\n', h)
    h = re.sub(r'<div class="plate"><h4>(.*?)</h4>', r'\n[color=#c9974a][font_size=24]\1[/font_size][/color]\n', h)
    h = re.sub(r'</?div[^>]*>', '', h)
    h = re.sub(r'<h3>(.*?)</h3>', r'\n[font_size=30][color=#dcd3c2]\1[/color][/font_size]\n', h)
    h = re.sub(r'<h4>(.*?)</h4>', r'\n[font_size=26][color=#c9974a]\1[/color][/font_size]\n', h)
    h = re.sub(r'<blockquote>(.*?)</blockquote>', lambda m: '[indent][i][color=#c8bfae]' + m.group(1) + '[/color][/i][/indent]\n\n', h)
    h = re.sub(r'<p class="sig">(.*?)</p>', lambda m: '[right][i][color=#c9974a]' + m.group(1) + '[/color][/i][/right]\n\n', h)
    h = re.sub(r'<p[^>]*>(.*?)</p>', r'\1\n\n', h)
    h = h.replace('<br>', '\n').replace('<i>', '[i]').replace('</i>', '[/i]').replace('<b>', '[b]').replace('</b>', '[/b]')
    h = re.sub(r'<[^>]+>', '', h)
    h = html.unescape(h)
    return re.sub(r'\n{3,}', '\n\n', h).strip()
def plain(h): return html.unescape(re.sub(r'<[^>]+>', '', h or ''))
out = []
for c in book:
    pre = bb(c['preface'])
    if c.get('relics'):
        pre += '\n\n' + ORN + '\n[font_size=30][color=#dcd3c2]Relics[/color][/font_size]\n[i][color=#a39a8b]' + plain(c.get('relics_intro')) + '[/color][/i]\n\n' + bb(c['relics'])
    pages = [{"title": c['name'], "by": c.get('sub', ''), "epi": c.get('epi', ''), "bb": pre}]
    for w in c['works']:
        pages.append({"title": w['title'], "by": plain(w['by']), "epi": "", "bb": bb(w['html'])})
    out.append({"id": c['id'], "name": c['name'], "sub": c.get('sub', ''), "pages": pages})
sys.path.insert(0, 'tools')
import codex_extra
out = codex_extra.add(out)   # the Godot build's own works (tools/codex_extra.py)
json.dump(out, open('data/codex.json', 'w'), ensure_ascii=False)
print('chapters', len(out), 'pages', sum(len(c['pages']) for c in out))
