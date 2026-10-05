# Secret of Diablo

A Secret of Mana style top-down world played like Diablo 2. Built in **Godot 4.3+**.

Current state: a playable **Necromancer sandbox** — one large open zone, the D2 Summoning and Poison & Bone trees plus a custom **Bone Melee** tree with Secret of Mana charge attacks, a day/night cycle with real darkness, a lantern-bearing companion, minions and a mercenary. No story or quests yet (see `PLAN.md`).

## Run it
1. Open Godot 4.3 (or newer), **Import** this folder (`project.godot`), press **F5**.
2. Or from a terminal: `godot --path .`

## Controls (Diablo 2 style)
| Input | Action |
|---|---|
| Left-click | Move / attack the monster under the cursor (hold to keep walking) |
| Shift + Left-click | Attack in place |
| Right-click | Use the right skill (hold to repeat casts; **hold to charge** bone melee, release to strike) |
| Click the skill icons beside the orbs | Choose left / right skill. While the picker is open, hover a skill and press **F1–F8** to bind it |
| F1–F8 | Switch right skill |
| 1–2 / 3–4 | Healing / mana potion |
| L | Plant / recall the lantern |
| T / A / Tab / H | Skill tree / Character / Automap / Help |
| `=` / N | Debug: gain a level / skip 3 hours |

**Controller:** left stick move, right stick aim (otherwise auto-targets ahead), A left skill, X right skill (hold to charge), B cycle hotkeyed skills, Y lantern, LB/RB potions, Start skill tree, Back character, D-pad up automap.

## What's in
- **Necromancer**: D2 Summoning and Poison & Bone trees, plus **Bone Melee** in place of Curses. Prerequisites, required levels (1/6/12/18/24/30), synergies, 20 levels per skill, 5 stat points + 1 skill point per level.
- **Bone Melee (Secret of Mana feel)**: every swing empties a stamina gauge (bar under your feet); attacking early does less damage. At full stamina, hold a skill to build charge levels (pips), release to unleash. Charge levels unlock at skill level 1/4/8; Ossuary Avatar adds a 4th, empowered level. Attack rating vs defense (misses), knockback, hit stun, and hit recovery (a big hit staggers you and breaks your charge).
  - Bone Blade, Bone Lash (yank enemies/corpses), Skull Crusher (slam/stun), Bone Scythe (sweeps/spin), Ribcage Guard (block/parry/reflect), Grave Spear (dash/pin), Corpse Splinter (shrapnel from corpses), Marrow Mastery & Marrow Drain (passives), Ossuary Avatar (transformation).
- **Light & darkness**: 20-minute day/night cycle with dawn and dusk. At night the world goes dark outside light sources; monsters hit 35% harder against targets standing in darkness, spot you from further away, and drop better loot. **Shades** rise only at night, are nearly invisible outside light and take +50% damage inside it; they melt at dawn.
- **Lantern bearer**: a tiny immortal, untargetable skeleton that carries your light. Plant the lantern (L) to hold an area lit (25% brighter) and recall it later. Camp fire, Fire Golem and Fire Wisps also light the dark.
- **Corpses**: monsters leave corpses used by Raise Skeleton, Skeletal Mage, Revive, Corpse Explosion and Poison Explosion.
- **Minions**: skeletons, elemental skeletal mages, 4 golems (one at a time), revived monsters; they follow you and engage nearby enemies.
- **Mercenary**: a Pandoran Guard spearman who levels with you and returns 25 s after dying.
- **World**: a 200×200-tile procedural zone (forests, lakes, roads, bridges), camp in the centre, monsters get stronger with distance, champion packs, automap with fog of war.
- **Loot (minimal)**: gold and potions. Itemization comes later.

## Art & imported areas
Everything is drawn with placeholder art in a SoM-like style until real art is imported.
- **Your own game exports** → `assets/rip/` (step-by-step guide in `assets/rip/README.md`), then
  `godot --headless --path . --script res://tools/import_rip.gd` builds zones in `assets/zones/` and sprite sheets in `assets/sprites/`.
- **F10** travels between the procedural wilderness and imported zones (your character comes along).
- **F9** in a zone opens the collision painter: drag to paint solid / walkable, Shift+click marks a tile type solid everywhere, P sets the spawn; F9 again saves.
- Hand-made sprite sheets: see `assets/sprites/README.md`.

## Code map
| File | Purpose |
|---|---|
| `scripts/skill_db.gd` | All Necromancer skill data & formulas (tune balance here) |
| `scripts/skills.gd` | What each Summoning / Poison & Bone skill does when cast |
| `scripts/bone_melee.gd` | Bone Melee moves for every charge level, hit shapes, attack rating, knockback |
| `scripts/day_night.gd` | Day/night cycle and darkness |
| `scripts/lantern.gd` | Lantern bearer companion |
| `scripts/lighting.gd` | Light textures and falloff used by gameplay |
| `scripts/creature_db.gd` | Monster & mercenary stats |
| `scripts/player.gd` | Necromancer: input, stats, leveling |
| `scripts/creature.gd` | AI for monsters, minions, merc |
| `scripts/unit.gd` | Shared health/damage/curses/poison/movement + placeholder art |
| `scripts/world.gd` | Map generation, collision, pathfinding, bone walls, automap |
| `scripts/zone_editor.gd` | F9 collision painter for imported zones |
| `tools/import_rip.gd` | Importer: map layer PNGs → zones, screenshots/sheets → sprite sheets |
| `scripts/ui/hud.gd` | Orbs, skill bar, skill tree, character screen, automap |

## Tests
`godot --headless --path . res://tests/smoke_test.tscn` — boots the game, levels to 30, learns and uses every skill (bone melee at every charge level), checks parry, stagger, lantern, night, shades, death and respawn.
