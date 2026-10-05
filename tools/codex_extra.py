# Works written for the Godot build alone (not in the lore sources): appended to data/codex.json by codex_to_bb.py.
# Each: chapter id, title, "by" (the Stranger's note of how it came to him), bb (the page, in the Codex's BBCode).
H = lambda t: '\n[font_size=26][color=#c9974a]' + t + '[/color][/font_size]\n'
SIG = lambda t: '[right][i][color=#c9974a]' + t + '[/color][/i][/right]\n\n'
ORN = '\n[center][color=#8c6a37]❧[/color][/center]\n'
EXTRA = [
    ("roads", "What the Marked Carry",
     "Nailed inside the door of the way-house at Four Wents, under the tally of the dead. The hand is a road-warden's. The last line is in another hand, and newer.",
     "To all who take the roads past the ninth stone.\n\n"
     "Some of the dead come up wrong. You will know them by the way the others keep near them, as men keep near a fire. They go in packs, and a pack is all of one wrongness. Learn the wrongness before you learn the pack.\n"
     + H("The old marks") +
     "The [b]Heavy-Handed[/b] strike as if the arm were twice its weight. Do not trade blows with them.\n\n"
     "The [b]Quick[/b] close the ground before you have finished counting it.\n\n"
     "The [b]Stone-Skinned[/b] turn an edge. Bring something blunt, or something that is not a blade at all.\n"
     + H("The new ones") +
     "The [b]Ash-Trailing[/b] leave the ground hot behind them; you will see it smoulder. Fight them where they have not yet walked.\n\n"
     "The [b]Grave-Called[/b] do not fall alone. Where one goes down the ground gives up another. Do not stand over the body.\n\n"
     "The [b]Thirsting[/b] drink what you draw on: essence, breath, the sand in a glass, whatever it is you spend. Keep them off you, or keep it short.\n\n"
     "The [b]Nail-Fisted[/b] break your footing whatever you wear. A shield will not save you. Distance will.\n\n"
     "The [b]Thorned[/b] give back part of every close blow. Strike them from further off, or strike them once and well.\n\n"
     "Near a [b]Candle-Eater[/b] your lantern shrinks, as if something breathed on the wick. Kill it first, or you will not see the rest.\n\n"
     "The [b]Bursting[/b] do not lie still. The body swells and flies apart in bone. When it falls, walk away from it, not toward.\n\n"
     "The [b]Warded[/b] shrug off workings: blood, breath, the light and the dark all slide from them. Steel does not.\n\n"
     "The [b]Unquiet[/b] do not walk to you. They are simply nearer. If you turn your back on one, turn it back quickly.\n"
     + ORN +
     "The ones with names carry two of these once they have grown. I have seen one that carried three. I did not see it for long.\n\n"
     + SIG("Aldous Pell, warden of the Four Wents road") +
     "[i][color=#a39a8b]He carried this notice to the ninth stone himself, the winter after. They found the notice.[/color][/i]"),
]

def add(out):
    for cid, title, by, bb in EXTRA:
        for c in out:
            if c["id"] == cid and not any(p["title"] == title for p in c["pages"]):
                c["pages"].append({"title": title, "by": by, "epi": "", "bb": bb})
    return out

if __name__ == "__main__":
    import json
    d = json.load(open("data/codex.json"))
    json.dump(add(d), open("data/codex.json", "w"), ensure_ascii=False)
    print("extra works", len(EXTRA))
