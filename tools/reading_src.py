#!/usr/bin/env python3
# The Reading (character creation), written for the Godot build (2026-09-30). Replaces the web export as the source of
# data/reading.json. Every choice gives something and takes something, and they are weighed on one scale (VALUE below,
# "marks": one mark is about 3% of a pilgrim's strength). A plain choice gives about 2.2 marks and takes about 1.2; a
# face gives a tree +1 as well; a few are gambles (more given, more taken). The build prints anything off the scale.
# The words are the Stranger's: he reads for the Tithed at his fire; he has done it a long time; he is not kind, and he
# is not cruel either. Places and names are the Hide's (Act I) and the god's body below it.
import json, sys

# ---------------------------------------------------------------- the scale
VALUE = {'vit': 0.5, 'spi': 0.5, 'con': 0.5, 'life': 0.1, 'mana': 0.1, 'hpPct': 0.35, 'armor': 0.15, 'stam': 0.2,
         'lok': 0.6, 'mf': 0.12, 'gold': 0.06, 'xp': 0.4, 'dmg': 0.45, 'dmg_night': 0.25, 'dmg_day': 0.25,
         'raised': 0.15, 'fcr': 0.25, 'frw': 0.3, 'res': 0.2, 'res_fire': 0.08, 'res_cold': 0.08, 'res_poison': 0.08,
         'regen': 0.15, 'lrad': 0.12, 'potion': 0.1, 'skt0': 2.0, 'skt1': 2.0, 'skt2': 2.0}
LAB = {'con': ' Constitution', 'vit': ' Vitality', 'spi': ' Essence', 'life': ' life', 'mana': ' to your pool',
       'stam': ' poise', 'lok': ' life after each kill', 'armor': ' armor', 'mf': '% magic find', 'hpPct': '% life',
       'dmg': '% damage', 'dmg_night': '% damage in the dark', 'dmg_day': '% damage under an open sky',
       'raised': '% damage to the raised dead', 'fcr': '% faster cast rate', 'gold': '% gold found',
       'res': '% magic resist', 'res_fire': '% fire resist', 'res_cold': '% cold resist', 'res_poison': '% poison resist',
       'frw': '% faster movement', 'xp': '% experience', 'regen': '% faster refill', 'lrad': '% lantern reach',
       'potion': '% from draughts'}
CAPS = {'vit': 8, 'spi': 8, 'con': 8, 'life': 40, 'mana': 30, 'hpPct': 12, 'armor': 24, 'stam': 16, 'lok': 4,
        'mf': 30, 'gold': 40, 'xp': 10, 'dmg': 10, 'dmg_night': 15, 'dmg_day': 15, 'raised': 30, 'fcr': 12,
        'frw': 10, 'res': 15, 'res_fire': 30, 'res_cold': 30, 'res_poison': 30, 'regen': 20, 'lrad': 25, 'potion': 30}
TREES = {'animancer': ['Mirror', 'Soul', 'Thread'], 'hemomancer': ['Brood', 'Blood', 'Flesh'], 'ossumancer': ['Ossuary', 'Bone', 'Carapace'],
         'miasmancer': ['Miasma', 'Distortion', 'Death'], 'monk': ['Radiance', 'Absence', 'Destroyer']}

def worth(fx):
    g = sum(VALUE[k] * v for k, v in fx.items() if v > 0)
    c = -sum(VALUE[k] * v for k, v in fx.items() if v < 0)
    return g, c

def txt(fx, cls=None):
    good, bad = [], []
    for k, v in fx.items():
        if k.startswith('skt'):
            good.append('+%d to %s skills' % (v, TREES.get(cls, ['one', 'another', 'a third'])[int(k[3:])]))
        else:
            (good if v > 0 else bad).append(('+' if v > 0 else '') + ('%g' % v) + LAB[k])
    return ' · '.join(good + bad)

def E(id, name, emb, fx, say, rev=None, **kw):
    o = {'id': id, 'name': name, 'emb': emb, 'fx': fx, 'say': say}
    if rev:
        o['rev'] = {'fx': rev[0], 'say': rev[1]}
    o.update(kw)
    return o

# ---------------------------------------------------------------- the gods (already chosen at the title) and their faces
STARS = {
    'ossumancer': E('tower', 'Oss-Vharoth', 'skull', {'con': 3, 'armor': 6, 'fcr': -4},
        "Oss-Vharoth. The Standing Dead, the skeleton that would not lie down when the god fell. It held your cradle the way a grave holds a coffin. You will stand. You will not bend. You will break.", sub='the Standing Dead'),
    'hemomancer': E('wheel', 'Nol-Shogthuth', 'heart', {'vit': 3, 'potion': 10, 'res': -5},
        "Nol-Shogthuth, the flesh that keeps growing with no mind to stop it. The Wheel turns in her and she drinks what spills. She was ascendant, and she was thirsty. You will live long enough to regret it.", sub='Mother of the Wheel'),
    'animancer': E('lantern', "Yh'Anuul", 'spool', {'spi': 3, 'lrad': 8, 'armor': -6},
        "Yh'Anuul. The Veiled Crone, the god's soul, still at her loom though no hand works it. She drew one thread out of your cradle and held it up to the light. She has not put it down. Little thread. Little thread.", sub='the Veiled Crone'),
    'miasmancer': E('hollow', 'The Myriad', 'breath', {'res': 5, 'res_poison': 12, 'hpPct': -3},
        "The Myriad. Not one god: every stone and river and bell has a small spirit of its own, and they are choking on what the god breathed out when it fell. Your people bow to all of them. You will breathe their sickness so they need not.", sub='the Spirits in All Things'),
    'monk': E('silence', 'Ur-Nihl', 'blacksun', {'con': 2, 'dmg_night': 5, 'hpPct': -3},
        "Ur-Nihl. ... No. I will not look into the bowl for that one. See: the blood has gone still. Smooth as black glass. It is not a god that looked down on you. It is the hole the gods are lying in, and it was smiling.", sub='the Silence'),
}
FACES = {
    'ossumancer': [
        E('keeper', 'The Gravekeeper', 'grave', {'skt0': 1, 'armor': 5, 'frw': -4}, "The Gravekeeper, lantern low, counting his dead. He will lend you the ones he cannot fit in the ground. He walks slowly. So will you."),
        E('marrow', 'The Marrow-Eater', 'bones', {'skt1': 1, 'spi': 2, 'armor': -8}, "The Marrow-Eater cracks the bones to suck out what is inside. Hungry god. Hungry child. Thin skin, both of you."),
        E('wall', 'The Wall', 'stone', {'skt2': 1, 'con': 2, 'fcr': -5}, "The Wall. Bone on bone on bone. Behind it you will be safe. Nothing behind it is ever quick."),
    ],
    'hemomancer': [
        E('mother', 'The Brood-Bride', 'heart', {'skt0': 1, 'hpPct': 3, 'dmg': -3}, "The Brood-Bride. Every tumour is a child to her, and she would not strike a child. You will make a very good mother, and a poor butcher."),
        E('vein', 'The Open Vein', 'drop', {'skt1': 1, 'dmg': 2, 'hpPct': -4}, "The Open Vein. She never closed. She never will. Neither will you."),
        E('butcher', 'The Butcher', 'hammer', {'skt2': 1, 'con': 2, 'res': -6}, "The Butcher, apron stiff with it. She taught the golem how to stand. She never learned to keep a spell off her."),
    ],
    'animancer': [
        E('smith', 'The Soul-Smith', 'hammer', {'skt0': 1, 'armor': 6, 'fcr': -5}, "The Soul-Smith hammers breath into iron. The iron screams, and then it obeys. Everything obeys, in the end. Slowly."),
        E('bearer', 'The Lantern-Bearer', 'lantern', {'skt1': 1, 'regen': 6, 'armor': -8}, "The Lantern-Bearer. The wisps come to her like sparks to a draught. They will come to you. So will everything else."),
        E('speaker', 'The Speaker', 'mouth', {'skt2': 1, 'fcr': 4, 'hpPct': -4}, "The Speaker. Her words unmade a city. Yours will unmake smaller things. Begin with yourself."),
    ],
    'miasmancer': [
        E('breath', 'The Purifier', 'breath', {'skt0': 1, 'res_poison': 12, 'hpPct': -3}, "The Purifier. She draws the defilement out of the dead and binds it in paper. Breathe in what the world cannot bear, little doll. It will cost you room."),
        E('unseen', 'The Keeper at the Gate', 'door', {'skt1': 1, 'frw': 3, 'armor': -8}, "The Keeper at the Gate, who guards the spirit road. It is never where you look. Neither will you be. Pray nothing looks hard."),
        E('knell', 'The Bell-Rope', 'bell', {'skt2': 1, 'lok': 2, 'res': -6}, "The Bell-Rope, pulled to wake the spirits before a killing. One pull for every ending. It will be pulled for you too."),
    ],
    'monk': [
        E('laugh', 'The Laughing Face', 'sun', {'skt0': 1, 'dmg_day': 4, 'res': -5}, "The Laughing Face. It laughs at the sun for thinking it could clean anything. Laugh with it, and burn."),
        E('bowl', 'The Empty Bowl', 'bowl', {'skt1': 1, 'lok': 1, 'potion': 5, 'hpPct': -3}, "The Empty Bowl. Everything poured into it is gone. Beg with it, little monk. The world will fill it for you, a spoonful at a time."),
        E('unmoved', 'The Unmoved', 'mountain', {'skt2': 1, 'con': 2, 'frw': -4}, "The Unmoved. A mountain does not hate the valley. It simply falls on it, when it is ready. It is seldom ready."),
    ],
}

# ---------------------------------------------------------------- the old cards, drawn blind (upright, or reversed a third of the time)
CARDS = [
    E('digger', "The Gravedigger's Hands", 'hand', {'con': 3, 'armor': 5, 'frw': -4}, "You have buried more than you remember. Your hands have not forgotten. They are slow, and they do not tire.",
      ({'lok': 2, 'con': -2}, "Reversed, the hands dig their own grave. They are very good at it, and they eat well while they work.")),
    E('veil', 'The Singed Veil', 'flame', {'mf': 12, 'res_fire': 10, 'hpPct': -3}, "Drawn to every light that burns you. You will find pretty things in the ash, and the ash will find you.",
      ({'fcr': 5, 'mf': -8}, "The veil upside down: it has already burned. What is left of you is quick, and poorer for it.")),
    E('swaddling', 'The Swaddling', 'heart', {'hpPct': 5, 'potion': 5, 'dmg': -3}, "Soft. Warm. Wrapped against the ash. It will not last, but it will keep you a long while.",
      ({'dmg': 4, 'hpPct': -4}, "The swaddling reversed is the knife that cut it. Sharp, and nothing to keep you warm.")),
    E('gleaner', 'The Gleaner', 'bowl', {'gold': 20, 'mf': 6, 'res': -5}, "You will pick at what the others leave behind. So do I. The dead do not mind. Their gods do.",
      ({'mf': 12, 'gold': -15}, "The gleaner turned over picks only the bright things, and leaves the copper lying.")),
    E('saint', 'The Weeping Saint', 'weep', {'vit': 3, 'raised': 8, 'fcr': -4}, "She wept for all of you. None of you wept for her. The raised dead remember her, and fear what she weeps on.",
      ({'res': 8, 'vit': -3}, "Reversed, she stops weeping. Dry-eyed saints are hard to hurt, and hard to hold.")),
    E('scholar', "The Scholar's Eye", 'eye', {'spi': 3, 'xp': 2, 'con': -3}, "You will read the world closely. The world does not like being read. It will lean on you.",
      ({'xp': 4, 'spi': -3}, "The eye turned inward. You will learn a great deal about yourself. None of it will help you cast.")),
    E('hanged', 'The Hanged Twin', 'hanged', {'frw': 5, 'stam': 4, 'armor': -8}, "One of you hangs. The other runs. You know which one you are.",
      ({'armor': 10, 'frw': -4}, "Reversed, you are the one who hangs. Very still. Very hard to cut down.")),
    E('knot', 'The Knot of Mouths', 'mouth', {'lok': 3, 'hpPct': -4}, "Many mouths, one hunger. You will eat well at every grave, and go hungry between them.",
      ({'gold': 25, 'res': -5}, "The knot reversed hoards. It keeps what it bites, and bites what comes near.")),
    E('wick', 'The Wick', 'candle', {'fcr': 6, 'lrad': 6, 'hpPct': -4}, "You burn quickly. Everyone who burns quickly thinks it is a gift. It is, for a while. Everyone sees you coming.",
      ({'hpPct': 5, 'fcr': -5}, "The wick turned down. You will last the night. You will not do much with it.")),
    E('pilgrim', 'The Pilgrim', 'staff', {'stam': 8, 'frw': 3, 'dmg': -3}, "A long road, and nothing at the end of it. You will walk it anyway, and walk it well.",
      ({'dmg': 3, 'stam': -6}, "The pilgrim reversed has arrived, and is angry about what was waiting.")),
    E('mourner', 'The Mourner', 'weep', {'res': 8, 'regen': 4, 'xp': -2}, "Grief has made you hard to wound. It has made you slow to learn, too. You keep looking back.",
      ({'spi': 3, 'res': -6}, "The mourner turned away from the grave. Bright, and open to everything.")),
    E('key', 'The Ossuary Key', 'key', {'armor': 8, 'raised': 6, 'frw': -4}, "It opens every door in the house of bones. Only one of them lets you out. You will carry it a long time.",
      ({'mf': 12, 'armor': -8}, "The key reversed opens only the small doors. Strongboxes, mostly. Coffins.")),
    E('cup', "The Beggar's Cup", 'cup', {'xp': 3, 'potion': 5, 'gold': -15}, "Empty, always empty. You will fill it with the lives of others, and with whatever they spill.",
      ({'gold': 25, 'xp': -2}, "The cup reversed is full of copper. Heavy, and it teaches you nothing.")),
    E('bell', 'The Drowned Bell', 'bell', {'res': 6, 'res_cold': 12, 'frw': -4}, "It still rings under the fen. Everyone who hears it goes a little slower, a little safer, a little colder.",
      ({'frw': 5, 'res': -6}, "The bell reversed has stopped. The quiet makes you quick. It makes you careless too.")),
    E('coin', 'The First Coin', 'coin', {'lok': 2, 'gold': 10, 'armor': -8}, "The first thing you ever sold. It fit in your palm. You have been finding smaller things to sell ever since.",
      ({'armor': 10, 'lok': -1, 'gold': -10}, "Reversed, you kept it. Held tight. Hard as a clenched fist, and it feeds you nothing.")),
    E('kiln', 'The Kiln', 'kiln', {'dmg': 3, 'res_fire': 10, 'hpPct': -4}, "What goes in soft comes out hard, or does not come out. You came out.",
      ({'hpPct': 5, 'dmg': -3}, "The kiln gone cold. You are still soft. Soft things last, in their way.")),
    E('loom', 'The Unravelling Loom', 'spool', {'xp': 3, 'regen': 5, 'stam': -8}, "Someone is weaving you and someone is pulling the thread out, and they are working at the same speed. You learn fast. You tire faster.",
      ({'stam': 8, 'xp': -2}, "The loom reversed has stopped. You are finished. Finished things are sturdy, and they do not grow.")),
    E('lanternwright', 'The Lantern-Wright', 'lantern', {'lrad': 12, 'regen': 5, 'dmg_night': -5}, "The one who lit the first lanterns on the Hide. He gave the light away and kept none for his own hands.",
      ({'dmg_night': 8, 'lrad': -10}, "The Lantern-Wright reversed puts the lamps out. You will see less. What you see, you will kill.")),
    E('choir', 'The Drowned Choir', 'waves', {'regen': 8, 'mana': 10, 'hpPct': -4}, "They sang the fen to sleep and the fen took them down to finish the hymn. Their breath is yours now. Not their lungs.",
      ({'hpPct': 5, 'regen': -6}, "Reversed, the choir is silent and the water gives the air back. You breathe easy. You sing badly.")),
    E('tithe', 'The Tithe', 'coin', {'xp': 3, 'mf': 6, 'hpPct': -5}, "Every tenth of you belongs to the god. You were counted at birth, like all the Tithed. The god collects in blood, and it pays in lessons.",
      ({'hpPct': 5, 'xp': -2}, "Reversed, the tithe is forgiven. You keep the whole of yourself. You learn nothing by it.")),
    E('crown', 'The Hollow Crown', 'crown', {'dmg': 4, 'mf': 6, 'res': -8}, "A crown of bone, waiting for a head. It makes a king of anyone and a target of everyone.",
      ({'res': 8, 'dmg': -3}, "The crown reversed is a bowl. You will be humble, and hard to curse.")),
    E('unwritten', 'The Unwritten', 'feather', {'frw': 4, 'xp': 2, 'life': -15}, "A blank page. Nothing is written for you yet, so nothing can stop you. Nothing will hold you together either.",
      ({'life': 20, 'frw': -4}, "Reversed, the page is full, every line of it. Heavy with it. Hard to kill with it.")),
]

# ---------------------------------------------------------------- what you fear, what you go down for, how you came
FEARS = [
    E('dark', 'The dark', 'blacksun', {'lrad': 10, 'res': 5, 'dmg_night': -6}, "The dark. Good. It is the one thing down there that will never lie to you. Carry a bigger lamp, and never trust your blade in it."),
    E('fire', 'Burning', 'flame', {'res_fire': 15, 'vit': 2, 'fcr': -4}, "Fire. The Pyre-Saints walk the heath still, burning. You will stand farther from them than most. It will slow your hands."),
    E('water', 'Drowning', 'waves', {'stam': 8, 'res_cold': 10, 'frw': -4}, "Drowning. You will hold your breath a long time. Longer than the others. Not long enough, and heavy in the water."),
    E('crowd', 'Being surrounded', 'hand', {'armor': 10, 'stam': 4, 'dmg': -3}, "So many hands. You will learn to wear something thick and to stand firm. It will not be enough, but it will be nearly."),
    E('forgot', 'Being forgotten', 'feather', {'xp': 3, 'mf': 6, 'gold': -15}, "Forgotten. Then go and do something worth remembering. Quickly. It will cost you, and you will not mind."),
    E('hunted', 'Being hunted', 'shadow', {'frw': 5, 'lrad': 5, 'armor': -8}, "Hunted. You can hear it already, can you not? Run. Keep a light behind you and never wear anything that clanks."),
    E('mirror', 'Your own face', 'mirror', {'spi': 3, 'res': 5, 'vit': -3}, "Your own face. Wise. I have seen it. I would not look either. Look at the world instead; you will see it clearer."),
    E('hunger', 'Starving', 'bowl', {'lok': 2, 'potion': 10, 'stam': -8}, "Hunger. The dead are full of meat. You will learn not to mind. You will learn to eat on your feet, and to be tired."),
    E('bells', 'Bells', 'bell', {'frw': 4, 'res': 5, 'hpPct': -3}, "Bells. Yes. There is one in the ash that walks. You will know it by its ringing. Run sideways, not away."),
    E('hands', 'Hands in the dark', 'hand', {'armor': 8, 'dmg_night': 5, 'fcr': -5}, "Hands. They run on their fingers out there. Keep your back to a wall and they cannot come round you. Strike first."),
    E('silence', 'Silence', 'blacksun', {'spi': 3, 'regen': 5, 'hpPct': -5}, "Silence. Then you fear the right thing. The only thing. Most never learn to. It will eat at you from the inside."),
    E('dead', 'The dead getting up', 'bones', {'raised': 15, 'armor': 4, 'xp': -2}, "The raised. They stood up once; they will stand up again unless you make them stop. You will learn how to make them stop."),
    E('sickness', 'Sickness', 'breath', {'res_poison': 15, 'regen': 5, 'dmg': -3}, "The god's last breath sours in the low places. You will keep your mouth covered and your lungs clean, and you will strike gently."),
    E('god', 'That the god is not dead', 'eye', {'res': 8, 'xp': 2, 'gold': -15}, "That it is only sleeping. Clever. Frightened, and clever. The truth is worse, but you will not believe me, so pay attention instead."),
]
SEEKS = [
    E('vengeance', 'Vengeance', 'dagger', {'dmg': 4, 'lok': 1, 'res': -8}, "Vengeance. That door is heavy, and it only opens one way. You will go through hard and come out open."),
    E('knowledge', 'Knowledge', 'eye', {'xp': 4, 'spi': 2, 'dmg': -3}, "Knowledge. There is a library beneath the Crypt. Its books read you back. They teach well; they bite badly."),
    E('wealth', 'Wealth', 'coin', {'gold': 30, 'mf': 10, 'hpPct': -4}, "Copper. Of course. The dead do not need it, and they will not stop you. Mostly. You will carry it where your blood should be."),
    E('absolution', 'Absolution', 'saint', {'hpPct': 5, 'res': 5, 'dmg': -4}, "Absolution. From whom? Every god you could ask is dead or hungry. You will be hard to wound while you look. Gentle, too."),
    E('oblivion', 'Oblivion', 'blacksun', {'res': 8, 'dmg_night': 6, 'xp': -3}, "Oblivion. That door is always open. You need not hurry. You will be very good in the dark, and you will learn nothing on the way."),
    E('power', 'Power', 'crown', {'spi': 3, 'fcr': 4, 'vit': -4}, "Power. They all say power. They all looked like you when they said it. Thinner, afterwards."),
    E('home', 'A way home', 'door', {'frw': 5, 'stam': 4, 'armor': -10}, "A way home. There is no home. There is a road, and it is long, and it goes down. You will walk it lightly."),
    E('corpse', 'The dead god', 'skull', {'con': 3, 'vit': 2, 'fcr': -4, 'frw': -3}, "The dead god itself. Its heart is down there somewhere, under all of us. You would not be the first to go for it. You will need the shoulders for the digging."),
    E('faith', 'A god who answers', 'sun', {'res': 6, 'dmg_day': 5, 'gold': -15}, "A god who answers. Oh, they answer. That is the whole trouble with them. Stand in the light when you ask."),
    E('kin', 'Your kin', 'heart', {'hpPct': 4, 'potion': 10, 'mf': -8}, "Your kin. The Tithed scatter like seed. Some of them took root in very strange places. You will stay alive to find them, and find little else."),
    E('end', 'The end of all of it', 'blacksun', {'dmg': 4, 'dmg_night': 4, 'xp': -3, 'hpPct': -2}, "The end. You would hand the world to the Silence? Then you had better be strong enough to carry it there. You will not grow wiser on the way."),
    E('cure', 'A cure', 'cup', {'res_poison': 12, 'regen': 6, 'hpPct': 2, 'dmg': -3}, "A cure. For what? For whom? Ah. For you. The fen has herbs that remember being people. Gather gently."),
    E('name', 'Your own name', 'feather', {'xp': 3, 'lrad': 6, 'gold': -15}, "Your name. Someone took it at the grave-mouth. It is written down there somewhere, in a hand you will know. Read everything."),
]
ROADS = [
    E('pilgrim', 'The Pilgrim Road', 'staff', {'frw': 4, 'stam': 4, 'armor': -8}, "The pilgrim road. Worn hollow by knees. Everyone on it was walking to a god who had already died. You walk well, and light."),
    E('river', 'The Black River', 'waves', {'res': 6, 'res_cold': 10, 'stam': -8}, "The river. It runs under the barrows and comes up cold. You still smell of it, and you are still tired from it."),
    E('ash', 'The Ash Road', 'flame', {'armor': 8, 'res_fire': 10, 'hpPct': -4}, "The ash road. Something burned at both ends of it. You walked through the middle and came out scorched and hard."),
    E('stair', 'The Ossuary Stair', 'bones', {'con': 2, 'raised': 10, 'mf': -8}, "The stair of bones. Every step was someone. You counted them, at first. The raised know you counted."),
    E('ditch', 'The Red Ditch', 'drop', {'lok': 2, 'dmg': 2, 'res': -8}, "The red ditch. It was a road once. Then the war came, and then the war stayed. You ate what you had to."),
    E('lampless', 'The Lampless Way', 'blacksun', {'dmg_night': 8, 'mf': 6, 'lrad': -10}, "No lamps on that way. You found it by touch. Your hands remember things your eyes never saw."),
    E('bells', 'The Bell Road', 'bell', {'fcr': 5, 'res': 4, 'stam': -8}, "The bell road. They ring for the dead up there, day and night. You learned to speak between the strokes. Quickly."),
    E('nowhere', 'No Road at All', 'eye', {'xp': 3, 'mf': 6, 'gold': -20}, "No road. You simply were here, one evening, by my fire, with empty pockets. That happens more than you would think."),
    E('fen', 'Through the Drowned Fen', 'waves', {'res_poison': 12, 'regen': 5, 'frw': -4}, "The fen. The water there is thick with the god's breath, and the reeds whisper. You breathe it easier now. You wade still."),
    E('wood', 'Out of the Hollow Wood', 'shadow', {'frw': 3, 'dmg_night': 6, 'lrad': -8}, "The Hollow Wood, where the trees are someone. You came out quick and quiet, and you never learned to carry a light."),
    E('heath', 'Across the Burnt Heath', 'kiln', {'res_fire': 15, 'con': 2, 'regen': -6}, "The heath, where the Pyre-Saints walk. You crossed it in one night without resting. You have not rested since."),
    E('shore', 'Along the Ash Shore', 'waves', {'gold': 20, 'mf': 6, 'armor': -8}, "The Ash Shore, where the grey sea gives up the drowned and their purses. You came with sand in your boots and copper in your hand."),
]
SACS = [
    E('name', 'Your name', 'feather', {'xp': 3, 'gold': 10, 'hpPct': -4}, "Your name, then. No one will speak it over your grave. There will be no one to speak. You will learn faster for being no one."),
    E('shadow', 'Your shadow', 'shadow', {'frw': 5, 'res': 4, 'hpPct': -5}, "Your shadow. Light as smoke without it. Thin as smoke, too."),
    E('eye', 'Your left eye', 'eye', {'dmg': 4, 'mf': 6, 'armor': -10, 'lrad': -5}, "The left eye. It saw too much kindness anyway. Now you will see only what you strike."),
    E('warmth', 'Your warmth', 'moon', {'res': 6, 'res_cold': 15, 'stam': -8}, "Cold, then. The cold keeps. The cold keeps everything."),
    E('mother', "Your mother's face", 'saint', {'spi': 3, 'regen': 5, 'vit': -4}, "Her face. Already gone. You will wonder, some nights, whose voice that was."),
    E('sleep', 'Your sleep', 'moon', {'fcr': 5, 'dmg_night': 5, 'hpPct': -5}, "No more sleep. No more dreams. You will not miss the dreams. Trust me. The nights are long, and yours."),
    E('voice', 'Your voice', 'mouth', {'con': 3, 'armor': 5, 'fcr': -6}, "Your voice. You will scream silently now, like the rest of us. Spells come hard without it."),
    E('luck', 'Your luck', 'coin', {'vit': 2, 'spi': 2, 'con': 2, 'mf': -15, 'gold': -15}, "Luck. Ha! You never had much. I will take what there is, and you will be strong, and nothing will ever fall your way."),
    E('hunger', 'Your hunger', 'bowl', {'lok': 2, 'potion': 10, 'gold': -20}, "Hunger. Strange gift to give. The dead will feed you instead, and you will never again spend copper on bread."),
    E('taste', 'Your sense of taste', 'cup', {'lok': 1, 'potion': 15, 'xp': -2}, "Taste. You will eat ash and marrow and drink what the Gravekeeper sells and not mind it. Good. That is most of what there is."),
    E('song', 'The last song you knew', 'bell', {'fcr': 5, 'regen': 5, 'spi': -3}, "The song. I will hum it sometimes. You will not recognise it. Your hands will be quicker without it in your head."),
    E('fear', 'Your fear of heights', 'mountain', {'frw': 5, 'stam': 4, 'armor': -10}, "You will not fear falling. You will fall a great deal, and you will get up faster for it."),
    E('tears', 'Your tears', 'weep', {'res': 8, 'raised': 8, 'vit': -3}, "Your tears. The Weeping Saint will have them; she runs short. You will never cry again, and the raised dead will know it."),
    E('years', 'Ten of your years', 'spool', {'xp': 4, 'spi': 2, 'life': -30}, "Ten years off the end of your thread. You will not miss them; you would not have reached them. You will learn as if you knew it."),
]

# ---------------------------------------------------------------- one question, asked of each pilgrim (three answers)
QUESTIONS = [
    {'q': ['When you woke in the ash, something was in your hand.', 'What was it?'], 'a': [
        E('stone', 'A stone', 'stone', {'armor': 8, 'con': 2, 'frw': -5}, "A stone. You held on to the world before you knew what it was. It will hold on to you. Heavily."),
        E('nothing', 'Nothing', 'hand', {'frw': 5, 'fcr': 3, 'armor': -10}, "Nothing. Empty hands run faster. They catch less, too."),
        E('hand', 'Another hand', 'hand', {'lok': 2, 'raised': 6, 'gold': -15}, "Another hand. Cold? It was cold. You have been holding the dead ever since.")]},
    {'q': ['There is a voice in the Drowned Fen that speaks to travellers.', 'When you passed, what did it say?'], 'a': [
        E('myname', 'My name', 'feather', {'xp': 3, 'regen': 4, 'mf': -8}, "Your name. So it knows you. Learn quickly, before it learns the rest."),
        E('babble', 'Nothing I understood', 'mouth', {'res': 8, 'res_poison': 8, 'dmg': -3}, "Nothing you understood. A mercy. Understanding is how it gets in."),
        E('yours', 'Your name', 'eye', {'mf': 12, 'gold': 15, 'hpPct': -4}, "My name? ...Then it is looking for me through you. Find it pretty things, little messenger.")]},
    {'q': ['Everyone here was buried once. The god made sure of that.', 'Who buried you?'], 'a': [
        E('mother', 'My mother', 'heart', {'hpPct': 5, 'potion': 5, 'fcr': -5}, "Your mother. She buried you gently. You will be hard to kill because of it, and slow to hurry."),
        E('stranger', 'A stranger', 'coin', {'gold': 25, 'mf': 6, 'xp': -2}, "A stranger, who took your boots for the trouble. You will learn to take boots too."),
        E('self', 'No one. I dug myself out', 'grave', {'con': 3, 'stam': 4, 'spi': -3}, "You dug yourself out. Your hands remember the dirt. Your spirit remembers less.")]},
    {'q': ['Suppose you find it. The dead god. Whatever is left of its heart.', 'What will you do?'], 'a': [
        E('bury', 'Bury it', 'grave', {'res': 8, 'raised': 8, 'dmg': -3}, "Bury a world. It would take a very long time. You have that, perhaps."),
        E('eat', 'Eat it', 'mouth', {'lok': 2, 'dmg': 2, 'res': -8}, "Eat it! Ha. Many have tried. The god is patient with its eaters. It becomes them, slowly."),
        E('wake', 'Wake it', 'sun', {'spi': 3, 'dmg_day': 5, 'vit': -3}, "Wake it. Then the Silence comes for you first. Remember I warned you.")]},
    {'q': ['The lanterns call you back each time you fall.', 'Why do you think they want you?'], 'a': [
        E('kind', 'Because they are kind', 'lantern', {'hpPct': 4, 'lrad': 8, 'mf': -8}, "Kind. Yes. Hold on to that one. Hold on hard."),
        E('use', 'Because I am useful', 'hammer', {'dmg': 4, 'hpPct': -5}, "Useful. A tool that knows it is a tool. That is almost a person."),
        E('hungry', 'Because they are hungry', 'mouth', {'gold': 20, 'lok': 1, 'res': -6}, "Hungry. Now you are thinking like one of us.")]},
    {'q': ['A beggar on the Pilgrim Road asks you for a copper.', 'She has no hands. What do you do?'], 'a': [
        E('give', 'Give her the copper', 'coin', {'res': 6, 'regen': 5, 'gold': -20}, "You gave. Put it in her mouth, I hope. Kindness costs on the Hide. It is still cheap at the price."),
        E('walk', 'Walk on', 'staff', {'frw': 4, 'gold': 10, 'hpPct': -4}, "You walked on. Most do. The road is long and she is on every league of it."),
        E('ask', 'Ask her where her hands went', 'hand', {'xp': 3, 'mf': 6, 'stam': -6}, "You asked. She told you. You will not sleep well tonight, but you know something now.")]},
    {'q': ['Down in the Crypt a door is marked with your face.', 'Do you open it?'], 'a': [
        E('open', 'Open it', 'door', {'mf': 12, 'xp': 2, 'res': -8}, "Of course you do. Everyone opens that one. Take what is behind it and do not look at what it looks like."),
        E('seal', 'Seal it', 'key', {'armor': 8, 'res': 5, 'mf': -10}, "Sealed. Good. Some doors are better as walls. You will be safer, and poorer."),
        E('knock', 'Knock', 'bell', {'raised': 10, 'dmg_night': 5, 'hpPct': -4}, "You knocked. Something knocked back. It knows your hand now, and you know its.")]},
    {'q': ['Tell me true. When you are hurt,', 'what do you do?'], 'a': [
        E('fight', 'Strike back', 'dagger', {'dmg': 3, 'lok': 1, 'armor': -8}, "You strike back. The Hide is full of your sort. It is emptier every year."),
        E('flee', 'Run', 'shadow', {'frw': 5, 'potion': 5, 'dmg': -3}, "You run. Wise. The ones who stay are the ones I read for next."),
        E('endure', 'Stand and bear it', 'stone', {'stam': 8, 'hpPct': 3, 'frw': -4}, "You bear it. Stone does that. Stone is also what they build graves with.")]},
]

PROPHECIES = [
    {'say': "You will die in the dark, and it will not be the last time."},
    {'say': "A crown of bone is waiting for a head. It is not particular about whose."},
    {'say': "Something below the Crypt has learned your name. Try not to answer it."},
    {'say': "The lanterns will keep calling you back. Ask yourself why they want you so badly."},
    {'say': "Three faces will want you. None of them will want you whole."},
    {'say': "Somewhere on the Hide a grave is already dug in your size. You will walk past it twice without knowing."},
    {'say': "You will meet a pilgrim of another order on the road who does not cast a shadow. Do not share their fire."},
    {'say': "Your lamp will gutter at the worst of it. Keep walking. The dark is only the dark."},
    {'when': ['dark', 'lampless', 'wood', 'sleep'], 'say': "You chose the dark more than once tonight. It chose you back. It will keep you, when the lanterns cannot."},
    {'when': ['wealth', 'gleaner', 'shore', 'stranger', 'hungry'], 'say': "You will be rich, for a while, in a place where nothing can be bought. Remember the beggar with no hands."},
    {'when': ['vengeance', 'fight', 'eat', 'ditch'], 'say': "You will find the one you want to kill. They will already be dead. Kill them anyway. It helps."},
    {'when': ['dead', 'stair', 'key', 'hand', 'knock'], 'say': "The raised dead will learn to know you by your walk. Some of them will kneel. Do not let that comfort you."},
    {'when': ['fire', 'ash', 'heath', 'kiln'], 'say': "The Pyre-Saints will call you sister, or brother. Do not stand close enough to hear the rest."},
    {'when': ['water', 'river', 'fen', 'bell', 'babble'], 'say': "The drowned choir will sing your name one night. Do not hum along."},
    {'when': ['corpse', 'wake', 'god', 'bury'], 'say': "You will stand closer to the god's heart than anyone living. It will be beating. I am sorry."},
    {'when': ['home', 'kin', 'mother', 'kind'], 'say': "You will find someone who knew you before you were buried. They will not be glad."},
]
ASIDES = {
    'fear': ["You flinched. Where the Tithed walk, flinching keeps you alive. Fools call it cowardice.",
             "I will not laugh at what you fear. I fear things too. Worse things.",
             "Everyone is afraid of something down there. The brave just are not paying attention."],
    'seek': ["Some go down for copper, some for gods. The god does not care why. It eats both.",
             "You want something. It is written all over you, in a hand I do not like.",
             "Wanting is good. It keeps the feet moving when the rest of you would sit down."],
    'road': ["Every road on the Hide ends here, at my fire, sooner or later. Mine did.",
             "Your boots tell me before you do. Go on, say it anyway."],
    'ask': ["One more question. I always ask one. It is the only one that matters, and you will not know which it was.",
            "Answer quickly. The first answer is the true one. The second is the one you wish."],
    'sac': ["We are nearly done. This is the part that hurts.", "Do not look away from the knife. It is rude.",
            "Everyone gives something. The ones who give nothing are the ones I bury."],
}

# ---------------------------------------------------------------- the tuner: keep each choice's costs as written (they are
# its flavour), and scale what it gives until it gives about one mark more than it takes (a face about two, with its +1)
STEP = {'life': 5, 'mana': 5}
def tune(fx, target, tol=0.2):
    fx = dict(fx)
    gains = [k for k, v in fx.items() if v > 0 and not k.startswith('skt')]
    if not gains:
        return fx
    for _ in range(60):
        g, c = worth(fx)
        net = g - c
        if abs(net - target) <= tol:
            break
        # nudge the gain whose step best closes the gap, never below one step
        best = None
        for k in gains:
            st = STEP.get(k, 1) * VALUE[k]
            want = 1 if net < target else -1
            if want < 0 and fx[k] - STEP.get(k, 1) <= 0:
                continue
            after = abs(net + want * st - target)
            if best is None or after < best[0]:
                best = (after, k, want)
        if best is None or best[0] >= abs(net - target):
            break
        fx[best[1]] += best[2] * STEP.get(best[1], 1)
    return fx

def tune_all():
    for s in STARS.values():
        s['fx'] = tune(s['fx'], 1.3)
    for fs in FACES.values():
        for f in fs:
            f['fx'] = tune(f['fx'], 1.85)
    for c in CARDS:
        c['fx'] = tune(c['fx'], 1.0)
        c['rev']['fx'] = tune(c['rev']['fx'], 1.0)
    for lst in (FEARS, SEEKS, ROADS, SACS):
        for x in lst:
            x['fx'] = tune(x['fx'], 1.0)
    for q in QUESTIONS:
        for a in q['a']:
            a['fx'] = tune(a['fx'], 1.0)

# ---------------------------------------------------------------- check the scale and write the data
def check():
    bad = 0
    def one(tag, fx, lo, hi):
        nonlocal bad
        g, c = worth(fx)
        if not (lo <= g - c <= hi) or c < 0.8:
            print('OFF %-34s gives %.2f takes %.2f net %+.2f' % (tag, g, c, g - c)); bad += 1
    for cls, s in STARS.items():
        one('star ' + cls, s['fx'], 0.9, 1.7)
    for cls, fs in FACES.items():
        for f in fs:
            one('face %s/%s' % (cls, f['id']), f['fx'], 1.5, 2.2)
    for c in CARDS:
        one('card ' + c['id'], c['fx'], 0.7, 1.4)
        one('card ' + c['id'] + ' rev', c['rev']['fx'], 0.7, 1.4)
    for k, lst in [('fear', FEARS), ('seek', SEEKS), ('road', ROADS), ('sac', SACS)]:
        for x in lst:
            one(k + ' ' + x['id'], x['fx'], 0.7, 1.4)
    for q in QUESTIONS:
        for a in q['a']:
            one('ans ' + a['id'], a['fx'], 0.7, 1.4)
    return bad

def finish(o, cls=None):
    o = dict(o)
    o['txt'] = txt(o['fx'], cls)
    if 'rev' in o:
        o['rev'] = dict(o['rev'], txt=txt(o['rev']['fx'], cls))
    return o

if __name__ == '__main__':
    tune_all()
    n = check()
    out = {'caps': CAPS, 'value': VALUE,
           'stars': {c: finish(s, c) for c, s in STARS.items()},
           'faces': {c: [finish(f, c) for f in fs] for c, fs in FACES.items()},
           'cards': [finish(c) for c in CARDS], 'fears': [finish(x) for x in FEARS], 'seeks': [finish(x) for x in SEEKS],
           'roads': [finish(x) for x in ROADS], 'sacs': [finish(x) for x in SACS],
           'questions': [{'q': q['q'], 'a': [finish(a) for a in q['a']]} for q in QUESTIONS],
           'prophecies': PROPHECIES, 'asides': ASIDES}
    s = json.dumps(out, ensure_ascii=False)
    for w in [' moth ', 'crow ', 'rat ', 'dog', 'lamb', 'bird', ' rot', 'Friday', 'mile', 'penn', 'countr', 'mana ', 'stun', 'loot']:
        if w.lower() in s.lower():
            i = s.lower().index(w.lower()); print('WORD?', w, s[i - 50:i + 30])
    json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else 'data/reading.json', 'w'), ensure_ascii=False, indent=1)
    print('ok', n, 'off the scale;', {k: len(v) for k, v in out.items() if isinstance(v, list)})
