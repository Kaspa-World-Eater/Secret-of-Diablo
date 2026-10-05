<!-- Start · updated 2026-09-30 · 3568 words · source page #rules -->
# 01 · The user's rules and the decision log

*These are law. Each came from the user. When a rule changes, edit it here and add a dated line to the log at the bottom.*

## How to work (process)

- **Small, reviewable steps.** A playable demo for every step change. Never a massive change made without the user's insight.

- **One piece at a time**, approved before the next. The user was upset when many agents ran at once and changed too much.

- **Status reports.** Prompt, clear updates; no long silent stretches. Keep the workshop board current with snapshots.

- **Say the plan first** for big changes, and wait for a go.

- **Midjourney prompts:** one full prompt per view, never one prompt plus view notes.

- **Check facts before stating them.** Never guess how something was made.

- **PixelLab:** Claude drives it so the user doesn't have to be present. The token lives only in `~/.pixellab/token`; never print it or put it in files. Never delete the user's PixelLab characters; the user does that.

## Gameplay law

- **No cooldowns anywhere.** Power is gated by cost (life, resource, poise, minions), never timers, and no durations that read like cooldowns.

- **Melee costs poise, never mana**, for every order.

- **Boss fights are Diablo-style, never Dark Souls-style:** never lock the player in a small room. You can run, kite and leave as much as you need (v75).

- **Every danger is plainly seen** (2026-09-30): no Diablo IV-style deaths to things you could not see — ground effects lost in clutter or the dark, detonations after a death with no tell, blows from off screen. Ground hazards, bursts and fires are fine when highly visible (Ash-Trailing's smouldering ash, the Bursting deed, the Pyre-Saint's eruption and fires). Tells and hazards draw unshaded so the dark never hides them.

- **Monster marks are Diablo II's kind only** (2026-09-30): no Diablo III / IV affixes (beams, orbiting fire, burning trails and the like).

- **Lantern perks are benign:** slow, fear, regeneration, radius. **Never damage.**

- **Loot is scarce**, as in Diablo 2: you should see items, but never a flood of magic and rares.

- **Gold is the currency** (the user prefers it to PoE-style currency-as-crafting).

- **Openness:** zones are open and spacious like D2's Act 1 and Act 5; few narrow corridors. Trees were thinned on purpose. "Some channeling things" are fine: a few loose tree lines and ruins per zone (v89).

- **Maps are random** per new game and Continue; towns and quest vaults are hand-laid.

- **Packs are 15% smaller** (not smaller monsters).

- **Poise break:** a short stun, a burst refill to half, then normal regen; **no rolling until poise is full**.

- **Monsters loiter like D2's imps** and should be bold, not cowardly (v76; +20% bolder in v79).

- **No strobing light.** Flames swell and gutter slowly; no fast flicker (v79).

- **Skill trees:** three per order, D2 layout, rows at levels 1/6/12/18/24/30; no capstones; a few clear synergies; every order has a viable melee and caster style; no weak level-1 minions without a point; no level-1 skill that needs a later one.

- **The Reading:** every percent effect is ±1% at most; flat values small.

- **Major Arcana** never give +skill levels and never add waits.

## Art and presentation law

- **No red lighting.** Ignore Midjourney's red key light; it's the tool's habit.

- **The Hemomancer's skin reads dark brown.** He is a Black man, drawn with dignity. Penitent, not tribal, not a mummy; no head cage.

- **No glows or effects on attacks and casts.** Ground it in realism.

- **Heroes' hands stay free** (weapons are separate layers, coming later).

- **No corny markers** (no "!" over things). The player learns from visual cues.

- **Gritty and dark.** The light comes from the **lantern, not the hero**: a pool on the ground that pushes the dark back, deepening outward like a cave, never pitch black; easier to see by day. "Useful in the game but not intrusive." A faint ring at the pool's edge is fine.

- **The hero casts a real shadow**; no dark blob under the feet. Wisps cast light but no shadow.

- **Never 3D-looking.** Flat, decided value shapes; no gradients, tubes or balloons. (The user rejected "old school 3D" three times.)

- **Use the user's own art directly** where it exists. Never sacrifice detail.

- **Grimdark knight standard:** realistic proportions (7.5–8 heads), harsh light, muddy desaturated palette, worn and tattered; one bold saturated mass per figure.

- **Atmosphere** is subtle, rare and comes from the world (no screen-overlay flecks).

- **No animals, no animal motifs** (no foxes, fur, birds). Every creature is a piece of the god.

- **No yin-yang** (non-duality is implied only).

- **The world has organic hints** in Act I (the god's body showing through), and a quiet dead-cow homage (never overt).

## Words

- **No science words in the world's voice:** never "cell", "virus", "DNA", "organism", "biology" and the like. The world speaks in flesh, bone, breath, blood, marrow.

- **The Ossuarch's order is the Pale Order.** Locked. (It was briefly "the Chapter of the Frame".)

- **Never used in the game:** cooldown, dps, proc, aggro, loot, buff, nerf, stun, lightning (as a word), mana (except as code), chain lightning.

- **2026-10-01 (Derek): PixelForge is the game's forge, for this game and the next.** All art tooling goes through it (`tools/pixelforge`), stays in theme (near-black, bone, iron, dull teal; amber only for lanterns and the Empty Hand's sand; blood dark; glow only on magic, lanterns, wisps), and ships with its Godot add-on so another project can use it unchanged.
- **2026-10-01 (Derek): the Hollow Mystic's carve is the reference fit.** Derek judged the form-fitted carve "much better" (cloak pulled to 0.8 of the side sweep, rounded cross-sections, no protrusions). Every character carve uses these defaults (`depth_scale` 0.8, `fit` 2.6) unless a sheet needs otherwise.
- **2026-10-01 (Derek): every hero carries a lantern.** The lanterns are painted as objects (one per order, in `docs/ART_ORDER.md`) and built through the Forge like any prop.
- **2026-10-01 (Derek): the Shrine Keeper's stacks are Omens**, not Sigils ("let's use omens over sigils"). The Word skill's drawn *sigil* stays a sigil; the Ossuarch's *count sigils* stay.
- **2026-10-01 (Derek): crows are allowed.** The "no animals" rule does not cover the crows in the moor (and the audit's "crows" rows are closed).
- **2026-10-01 (Derek): the wraith test skin is the Hollow Mystic.** `art/sprites/wraith.*` (made by the Forge) is his look; `--skin=wraith` on the Hollow Mystic is the look test.
- **"Rot" is never used** for miasma, the Shrine Keeper or anything else.

- The Hemomancer's goddess is the **Bleeding** Maiden, never "Weeping".

- "Minor Arcana", not "nodes" or "knots".

## Decision log (newest first)

- **2026-10-01, the look going forward (Derek, confirmed):** Diablo II sprites lit by a real 3D lantern. The game stays 2D pixel sprites made by the Forge (pre-rendered from carved models), standing as upright cards in the real-3D scene of `tests/scene3d` (orthographic 30° camera, real lantern light with stepped falloff, real shadows; normal + depth maps per frame from the Forge make the cards light like bodies). Not full 3D models in-game. The browser build's look and behaviour remain the reference for the port; its lighting is rebuilt on the 3D scene with the browser as the target.
- **2026-10-01, glows:** glows are fine on magic, lanterns and wisps. The rule is against a Diablo III look with glow on everything; attacks and plain melee stay unlit, the dark stays blue-teal, no red light. (Derek, to the PixelForge session.)
- **2026-10-01, PixelForge merged:** the asset forge lives at `tools/pixelforge/` in this repo. It replaces Marrowpress for anything that needs side or back views. The wiki is copied into `docs/wiki/`.

- **2026-09-30, skill trees:** every Mastery is a level-30 skill, and the trees intersect the way Diablo II's do (two-parent skills, lines crossing columns). The Hemomancer is shown as **the Red Penitent** (Mortification · Blood · Iron Maiden; mutations are **penances**); every skill does one thing no other does. The Ossuarch: Ossuary · Carapace · the Count (melee and numerology curses, small white strand-sigils over the cursed). The world has no Friday (fast-day).

- **2026-09-30, Godot:** the Stranger's box is the title (the user's favourite of three). He whispers of the order whose card you linger on, and draws its card from his deck when you begin. **Champion deeds** (one per pack, two for grown uniques): Grave-Called, Thirsting, Nail-Fisted, Thorned, Candle-Eater, Warded, Unquiet. The first reading of the rule cut Ash-Trailing, Bursting and the Pyre-Saint's death eruption; all came back the same day once the user explained he meant Diablo IV's invisible deaths, not visible hazards. Ash now smoulders unshaded and burns only once settled.

- **2026-09-29, the Unfallen:** the Pale Order believes the stars are pieces of the god's bones that have not yet fallen to rest. **Bone Rain** asks them to come down early.

- **2026-09-29, the Pale Order counts:** numerology joins the Order's theme. Numbers outlast names (the Hush unsays names), every bone gets its number in the Great Count, and counts are reduced to roots. Nine is the Mother's root ("nine keeps itself"). A man is two hundred and six bones, and the fewer is the holier. The Last Number closes the Count and lets her rest. The Count rises (implied only). See the Ossuarch page, §3.

- **2026-09-29, the Codex is mostly voices:** the main body of the Codex is in-world writing by many characters (sages, clerics, beggars, pilgrims, penitents, ancient things from before the Last Breath). Each chapter is a collection of works on its subject; found fragments are one part.

- **2026-09-30, v101:** music back to Claude's original v97 score (the user: "your music was better"). **The Codex is written entirely in-world:** every writer believes they live in this world and that what they write is true, never a tutorial or wiki voice. Everything not in another character's voice is written by the **Sage, the Mysterious Stranger**, who compiles the book: a letter to the reader opens it, and he wrote every chapter's preface, relics, carving notes and epigraphs anew (`wiki/11a-codex-stranger.md`). His facts so far: began the book in 1109 of the Last Breath, the letter is dated 1114; nine winters in the Ossa from 981; first climbed the Peak 1071; the Peak fell in spring 1098; he was the unnamed copyist in several works.

- **2026-09-29:** development moves toward **Godot 4.7.2** (installed portable on the Desktop; project at `Desktop\Godmarrow\Godot Project`). Vertical slice first: the Ashen Moor camp, road, chapel, Kneelers, loot, orbs, music. See `13-godot.md`. The web build stays the reference and playable demo meanwhile.

- **2026-09-29, v99:** lore: **Ossuarchs walk the Pale**, a path (see class-ossuarch, the Codex's Pale Order chapter and the Pale-Stone relic). Music: the v97 pieces come back as each place's **second movement** (slowed, drums in one section of three, the cello joining); places alternate the cello movement and the second movement every few minutes. The user likes both directions.

- **2026-09-29, v98:** music is drearier and led by a sad cello (bowed synth with late vibrato and glides) that sings each place's tune slowly and low; drums only now and then; long silences. Each act follows its land's culture: I the Moor's pilgrims (medieval minor, slow lute, frame drum); II the Pale Order's Barrens (harmonic minor, bass choir of brothers, tolling bells, rare great drum); III Shog-Mire and the Flesh (phrygian lament, muffled procession drum and rolls, the mud's heartbeat, a short strum); IV An-Vhar and the Gilded Peak's mountains (five-note mountain mode, temple bells, bamboo flute, one great drum); V the Descent (locrian, heartbeat, unresolved choir, distorted drone). Bosses: thunder drums under a driving cello in the act's mode. The v97 desert lute and jungle log drums are gone (they matched Diablo II's lands, not ours).

- **2026-09-29, v97:** new score (`zz_zz_music96.js`), live-synthesised in the manner of Diablo II and Lord of Destruction; no melody or sample copied. A cue per act and place: Act I camp is a fingerpicked twelve-string in 6/8; wilderness is long silences, wind, drones, reversed guitar and lone harmonics; dungeons are sub drones, clusters, scrapes, heartbeat drums and far bells; Act II is an oud-like lute in hijaz over darbuka; Act III is log drums in three-against-four, flute and marimba; Act IV is strings, low horn, men's choir and bells; Act V is a choir at the gate, then an industrial inferno; bosses get thunder drums, a phrygian ostinato and choir stabs with act colours. Each cue has its own seeded motif. The title screen now has music. Phone tome: the close button sits in the index leaf's top corner. Codex interviews: every Codex character was interviewed (beliefs, home, days, fears, the other orders); notes in `wiki/12-lore-notes.md`, full text in `wiki/12b-codex-interviews.md`. Nothing from the interviews is canon until adopted.

- **2026-09-29, v96:** the Codex is mostly **voices**: 66 in-world works written in character (pilgrims, brothers, sages, beggars, children, and a few prehuman things from the Held Space), gathered into nine chapters: The Reliquary; The Roads and the Stones; The Pale Order; The Gilded Peak; The Polished Heart; The Precious Wound; The House of Eight Million; Before the Last Breath; The Feuds. Each chapter is a preface, its works, then Relics and Rites. The in-game tome and the web Codex are generated from one source (`lore/chapters.py` plus `lore/voices/*.md`, via `lore/gen.py`). The tome got bronze corner guards with rivets, stacked page edges, a gutter, a ribbon, illuminated initials, a cup stain and a torn corner. The Ossuarch's skill flavour text is rewritten in the Pale Order's voice (the Tibetan terms are gone); Bone Rain is the Unfallen asked down early.

- **2026-09-29, v95:** waypoints are **waystones**. They look like ancient stone shrines, a broken ring of fang-shaped standing stones round a sunken pit, with only traces of biology: a dark wet something under an ash crust that breathes, stains seeping from the plinths, pale fibres in the ground. Travelling: you walk in, sink, and dissolve into blood, bone and viscera; the stones close; black; at the destination the matter draws back together and you rise out of the pit, wet. The title menu words hold still, with no dark box, and are brighter and larger.

- **2026-09-29, the Codex while we build:** The Codex (on the title screen) shows every chapter for now, so the lore is easy to find during development. When the game is ready it will fill in as players learn things in play.

- **2026-09-29, v94:** the Ossuarch's order is **the Pale Order** (locked). The title screen gains **The Codex**, a readable lore book styled as an ancient bronze-bound tome. The title menu is cast in old pitted bronze. The Trial of Thirty character starts with every waypoint kindled.

- **2026-09-29, v93:** **Soul Leash** moves to the Thread tree (row 18, under Needle's Mark). It is now a burst: every wisp throws a thread to an enemy within 5 yd for about 3–4 s; the held enemy burns and anything crossing a thread is cut, and the threads sweep as the wisps move (no wisps: three weaker threads from the hero). Its replacement in the Soul tree is **Procession** (hold: the choir circles the cursor in a ring and strikes inside it, costs Essence while held). **Burrowed creatures** can no longer be targeted by the wisps. **The white line was the melee swing arcs** drawn on every normal attack; removed (no light on attacks).

- **2026-09-29, Ossuarch lore, fourth pass.** The order **reveres bone**. Dropped: iron as a theme, the mills and bellows, and "the Knitting" (that is the Hollow Mystic's flavour). **The growth is never said**, only implied (a count that keeps rising, rooms nobody dug, dust that weighs more); the skills and art show it openly.

- **2026-09-29, the Bone grows.** A dark theme for the Ossuarch: the Bone grows, encroaches, calcifies and spreads like a cancer. His skills show it, with bone growing over his weapons, over his armour and in his enemies. The Chapter uses iron as a trellis for the growth and prunes it back each morning. In the doc's hidden layer, the growth is what the Mother has become, and the ossuaries are a quarantine.

- **2026-09-29, third pass on the Ossuarch and Empty Hand lore.**

- **Ossuarch:** no pregnancy, no lavras, no eating dust. **The Chapter of the Frame**: ancient (it claims as old as the world), keeping ossuaries built over older unknown ruins. It serves the **Bearing Mother**, tends bone and marrow, and makes the dust sacred (the only thing that has finished dying). **Sky funerals**, and it **hides something**.

- **Empty Hand:** the original order lore is restored and deepened. **Radiance is erasure by light** (the Peak's gold), and Absence is erasure by dark. The lore is about the order; the man is a beggar-monk of the same order, not the legend, and a mystery.

- **Both:** written Dark Souls style (fragments in game, the truth only in the doc).

- **2026-09-29, Empty Hand lore: second pass.** The user liked 90% of the original lore; only his personal story needed changing. The Gilded Peak, the Kinrei-shū, the chanting, non-duality, the courtyard of glass, the bowl and the black-flame lantern are restored. Gone: the mask (even as gear), the fasting-and-eating story, and anything that explains him. He is starved and gone, and the empty hand is read as the two trees: **open = Radiance, closed = Absence**. He is told only through hearsay that contradicts itself; for all anyone knows he is immortal.

- **2026-09-29, Ossuarch lore redone again.** The Atlant, Vault and Khrebet version was not liked. Now: **the Bearing Mother stays** (the Bone is pregnant with something); the **mountain bone monasteries (lavras)**; **raised dead power the mills and bellows** of their cities; bone grinds to **sacred dust**. The telling is Dark Souls style, esoteric and Lovecraftian: the game shows only fragments (item text, inscriptions, a hymn), and the truth stays in the doc.

- **2026-09-29, v92, the Empty Hand's lore brought up to date** ("not up to date with the character. No mask, called the Empty Hand"). He is the gaunt, barefoot beggar-monk. There is **no mask ever** (the later-gear mask is dropped). The name is the heart of the lore: he begs, he carries nothing, and what his hand closes on is gone. His order is the Brothers of the Bowl on the Kneeling Peak. They starved sitting, keeping their rule, and the Ossuarch's Levy came for their bones. The skill text now describes the man he is: no belly, gold, silks, Buddha or bodhisattva, and no "once every N s". Full page: `claude/godmarrow-class-kusho.md`.

- **2026-09-29, Ossuarch lore redone** ("no depth or feeling of ancient culture"). The Tibetan theme and the stone business are dropped. The new lore follows the user's direction: medieval knight, catacombs, mountains, grinding, Russian, stoic, eternal duty, a darker angel, bearing eternal weight; bone, brittle, dust, age, iron. The look is a colossal praetorian in bone and iron, never gold. His angel is **the Atlant**, who holds up the god's fallen skull, **the Vault**, over the mountain range **the Khrebet**. His order is **the Bearers** of **the Lower Lavra**. Full page: `claude/godmarrow-class-ossuarch.md`.

- **2026-09-29, v91:** chests "almost never drop anything". They were dropping, but the loot was hidden behind the big chest sprite. Loot now spills out in front of the chest, and the odds are slightly better. An empty chest is still allowed ("fine for them to drop nothing"), but it is rare.

- **2026-09-29, v90:** the two "chain lightning" Thread skills are made different: **Binding Thread** now threads nearby enemies to the one at the cursor, drags them in and strikes, jars and slows them on the snap; **Needle and Thread** stays the leaping dart. The Mystic's wisps are **one choir** (no types to choose); the wisp skills are passive **chances on each strike**: snag a thread (Wisps), pass on untired (Restless Dead), a needle through the foe (Darting Wisps), a spark splits off (Splitting Wisps).

- **2026-09-29, v89:** open zones get a few loose corridors (tree lines, broken colonnades; sometimes paired into lanes; always gappy) and lone wanderers (singles and pairs) in the quiet stretches. Openness still rules.

- **2026-09-29, v88:** hands that circled in fear now attack (a pre-existing bug; crowds send more in); shadows never darker than the dark; the white streak softened; mirror skills +20%; **gold drops silently**; drops raised toward D2 (about 7 items, 11 gold piles and 5 potions per 100 normal kills; magic and rare stay rare).

- **2026-09-29, v85–v87 ("do everything you want to do to enhance the game"):** decor casts lantern shadows; a boss slam leaves cracked ground (2.5 s, drains poise); moonlit clearings at night (rest: faster poise, slow healing); light shafts through the woods by day; world flames blocked by walls too.

- **2026-09-29, v84:** objects block the lantern's light and cast shadows (walls, cliffs, palisades, tree trunks, rocks, pillars); the light ring no longer just overlays.

- **2026-09-29, v83:** boss telegraphs (ground dust and grit, above the dark, never red, no glow) and a stagger meter under the boss's life; bosses left behind no longer heal.

- **2026-09-29, v82:** adopted from the game study: turning the wick down (risk/reward), the finishing blow on a reeling foe, the lantern keeping a little on each fall, drop sounds by rarity. **Declined:** a throwable light ("we don't need that for our base game").

- **2026-09-29, v81:** the choir also shapes the Mystic's spells (counts, duration, size), not only damage.

- **2026-09-29, v80:** wisps are **fuel**, not a gate: more wisps = stronger spells, fewer = weaker, 0 = a penalised spell (never refused). Wisps get more ethereal glow. The 20% stronger stagger applies to the **player** too.

- **2026-09-29:** "I prefer gold": gold stays the currency; no currency-as-crafting.

- **2026-09-29, v79:** lights strobed on mobile → all flames smoothed (no fast flicker); the pool has gentle stepped rings and more contrast; less warm glow (hero lights sized to the pool); monsters 20% bolder; stagger 20% stronger; no bright comet streak on darting wisps; **the Hollow Mystic's spells cost wisps**.

- **2026-09-29, v78:** world detail = non-solid per-land ground scatter + canopy dapple; no extra trees (openness).

- **2026-09-29:** the current Hemomancer ("Penitent") looks like a mummy, not brutal; **full redo later** (after the PixelLab reset on Oct 28, or from a user reference).

- **2026-09-29, v77:** cinematic pass approved in principle ("sounds good"): eye-shine, lantern-cast monster shadows, rare distant lightning, loot glints, lantern mood, blue-teal darkness.

- **2026-09-29, v76:** monsters were "a little too cowardly" → bolder; wisps "a little more glow".

- **2026-09-29, v75:** mobile was slow → automatic lighter mode (not download-only); no locked boss rooms ever.

- **2026-09-29, v74:** the lantern is **its own unit**: untargetable, hovers and follows closely, bound with a soul (the Wickbound lore).

- **2026-09-29, v73:** the hero casts a shadow; cinematography matters ("lighting drives moods and feelings").

- **2026-09-29, v70–v72:** lantern light tuning: v70 "too soft", v71 "too intense and stylized", v72 natural falloff accepted.

- **2026-09-29:** the Hollow King (zombie cow king) looked cartoony → back burner. Ossuarch out of commission. Armor tiers later.

- **2026-09-29:** use PixelLab animations (not PixelOver). Spend PixelLab generations to about zero and wait for the reset.

- **2026-09-28:** the game is named **Godmarrow**; gods are named the Dark Souls way (see 03).

- **2026-09-28:** Yh'Anuul is **Soul**; the Myriad is **Breath**.

- **2026-09-28:** the Kūshō is displayed as **The Empty Hand**; Weight meter and yin-yang orb removed; the hourglass orb.

- **2026-09-28:** body board: "Minor Arcana" instead of knots/nodes; each order has its own Major Arcana.
