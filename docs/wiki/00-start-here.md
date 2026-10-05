<!-- Start · updated 2026-09-30 · 1022 words · source page #start -->
# Godmarrow Wiki: start here

*Consolidated 2026-09-29 from every project doc and session note (up to demo v78). The wiki is the `wiki/` pages plus six reference docs that were already clean and stay at their `claude/` paths (the naming codex, the five class docs, the body board, the art-judge primer, the voice lines). The old overview, world, art, build, hero-bible, cinematography, motion-study and pipeline docs are superseded; if anything disagrees, **the wiki wins**.*

**Godmarrow** is a grimdark isometric pixel-art action RPG: Diablo 2's structure (acts, towns, waypoints, scarce loot, open fights), Path of Exile's depth (a huge passive board), and Dark Souls' feel (poise, stagger, readable tells, oblique lore). The world is the corpse of a dead god. You walk it with only a soul-bound lantern to push the dark back.

- **Read the lore:** The Ossuary of Words (the book, formerly the Codex of the Hide), [https://claude.ai/artifact/46JAa6mXqiFfApjzReVSYd](https://claude.ai/artifact/46JAa6mXqiFfApjzReVSYd) (nine chapters of in-world writings plus prefaces and relics; full text in project doc `wiki/11-codex-voices.md`; source in `lore/`, rebuilt by `lore/gen.py`).

- **Godot version (the main build now):** `wiki/13-godot.md` (where it is, what's ported, what's next). Arcana v103 (pathways between the Majors, the Mystic's cards rewritten and implemented): `wiki/15-arcana-v103.md`. Every mechanic to port: `wiki/14-mechanics-checklist.md`.

- **The Stranger's pages** (the book's own voice): `wiki/11a-codex-stranger.md`.

- **Lore notes from the interviews:** `wiki/12-lore-notes.md` (ideas to adopt or reject), full interviews in `wiki/12b-codex-interviews.md`.

- **Play the web demo:** [https://claude.ai/artifact/5wHDVwSeGwtzpUqpLa59Bp](https://claude.ai/artifact/5wHDVwSeGwtzpUqpLa59Bp) (current published version: **v103**)

- **Workshop board** (plan, snaps, log): [https://claude.ai/artifact/JeDyFJtvPeaMm4HhRHUVkW](https://claude.ai/artifact/JeDyFJtvPeaMm4HhRHUVkW)

- **Working title** was "Triune"; it survives as one of the dead god's names and in save keys (`triune.*`).

- **Platforms:** browser (the artifact), Windows/Steam Deck desktop app (Electron), Android APK; the Godot build on the user's Desktop (`Desktop\Godmarrow\Play Godmarrow (Godot).bat`).

## Pages

| # | Page | Read it when |
|---|---|---|
| 01 | `wiki/01-rules-and-decisions.md` | **Before any change.** The user's standing rules (law) and the dated decision log. |
| 02 | `wiki/02-world-and-lore.md` | Writing anything in-world: cosmology, acts, zones, towns, bestiary, landmarks, the Wickbound lanterns, voice rules. |
| 03 | `claude/godmarrow-naming-codex.md` | Naming a god, a place, or writing a line that mentions a god. |
| 04 | `wiki/04-systems-and-combat.md` | Gameplay: classes and resources, skills, poise, melee, the lantern and light, monsters, bosses, loot, the Reading, controls. |
| 05 | `claude/godmarrow-class-hemomancer.md`, `-hollow-mystic.md`, `-ossuarch.md`, `-shrine-keeper.md`, `-kusho.md` (the Empty Hand) | One order in depth: lore, trees, board, enemies, look, open questions. |
| 06 | `claude/godmarrow-body-board.md` | The Inverted Triune (passive web + tarot Arcana). v103 changes: `wiki/15-arcana-v103.md`. |
| 07 | `wiki/06-art-direction.md` | Anything visual: the art law, the hero family, lighting and cinematography, what's in the game now. |
| 08 | `wiki/07-art-pipelines.md` | Making art: PixelLab hero packing, world art, own-art on the grid, HUD, and the approaches that were rejected. |
| 09 | `claude/godmarrow-art-judge-primer.md` | Judging a piece of art against the references. |
| 10 | `wiki/08-tech-and-build.md` | Code, build, tests, publishing, the desktop and Android apps, where every system lives. |
| 11 | `wiki/09-backlog-and-open-questions.md` | What's next, what's parked, what the user still has to decide. |
| 12 | `wiki/10-study-great-games.md` | The study of PoE 1/2, Diablo II/D2R, Blasphemous and gritty pixel roguelikes, with lessons for Godmarrow. |
| 13 | `wiki/13-godot.md` | The Godot build: state, tools, next steps. |
| 14 | `wiki/14-mechanics-checklist.md` | Every mechanic with numbers and source files (the porting list). |
| 15 | `wiki/15-arcana-v103.md` | The body board's new roads and the Mystic's cards. |
| – | `claude/godmarrow-voice-lines.md` | Every line of in-game text (a readable copy of `src/zz_voice.js`; the source file is the truth). |

## The five orders at a glance

| Order (code id) | God (a speaker's name) | Resource | State in the demo |
|---|---|---|---|
| Hemomancer (`hemomancer`) | Flesh, the Bleeding Maiden | Vitae (skills cost life) | PixelLab sprite "Penitent"; **full redo planned** (reads as a mummy) |
| Hollow Mystic (`animancer`) | Soul, the Veiled Crone | Essence + the choir of wisps | PixelLab sprite "Trinkets"; good; the order ported to Godot first |
| Ossuarch (`ossumancer`) | Bone, Old Upright | Marrow (= mana) | **out of commission** (user); don't work on him |
| Shrine Keeper (`miasmancer`) | Breath, the Myriad | Miasma | old painter sprite, below standard |
| The Empty Hand (`monk`) | the Silence, the Hush | the hourglass (two sands) | approved HD monk |

## Glossary

| Term | Meaning |
|---|---|
| the Reliquary | the dead god's corpse, which is the world |
| the Hide | Act I; the god's skin and surface. Organic hints show through (ribs, veins, flesh, an eye-pool). |
| godmarrow | what still lives in the corpse's bones; every order draws on it |
| the Tithed | humans, descended from the congregation inside the god when it died |
| the Myriad | the god's last breath and the small spirits riding it |
| miasma | breath gone wrong. **Never "rot".** |
| the Wickbound | the soul bound in every lantern; your lantern follows you, carries you back when you fall, and "keeps a little" each time |
| the Reading | character creation, a tarot reading by the Mysterious Stranger |
| Minor / Major Arcana | small passive pegs / tarot cards on the body board |
| the Outer Circle, the rungs | v103 roads on the body board joining the Major Arcana |
| Heralds | rare god-altar bosses that grant Major Arcana |
| poise | stagger meter from Constitution; melee and rolls spend it |
| lighter mode | the automatic low-cost render mode on phones and slow machines (`window.__perf74.slow`, `?fx=lo`/`?fx=hi`) |

## How to use this wiki (for Claude)

- Read `01-rules-and-decisions` at the start of any session that changes the game.

- When the user makes a decision, add a dated line to the decision log in 01, and fix the page it touches.

- Keep one source of truth per fact: link rather than copy.

- Update the "current published version" line above after every publish.
