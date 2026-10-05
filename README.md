# Secret of Diablo

A Secret of Mana style top-down world played like Diablo 2. Built in **Godot 4.3+**.

Current state: a playable **Necromancer sandbox** — one large open zone, all 30 Necromancer skills, minions, a mercenary, D2 leveling. No story or quests yet (see `PLAN.md`).

## Run it
1. Open Godot 4.3 (or newer), **Import** this folder (`project.godot`), press **F5**.
2. Or from a terminal: `godot --path .`

## Controls (Diablo 2 style)
| Input | Action |
|---|---|
| Left-click | Move / attack the monster under the cursor (hold to keep walking) |
| Shift + Left-click | Attack in place |
| Right-click | Cast the right skill (hold to repeat) |
| Click the skill icons beside the orbs | Choose left / right skill. While the picker is open, hover a skill and press **F1–F8** to bind it |
| F1–F8 | Switch right skill |
| 1–2 / 3–4 | Healing / mana potion |
| T / A / Tab / H | Skill tree / Character / Automap / Help |
| `=` | Debug: gain a level |

## What's in
- **Necromancer**: all three D2 trees (Summoning, Poison & Bone, Curses), 30 skills, prerequisites, required levels (1/6/12/18/24/30), synergies, 20 levels per skill, 5 stat points + 1 skill point per level.
- **Corpses**: monsters leave corpses used by Raise Skeleton, Skeletal Mage, Revive, Corpse Explosion and Poison Explosion.
- **Minions**: skeletons, elemental skeletal mages, 4 golems (one at a time), revived monsters; they follow you and engage nearby enemies.
- **Mercenary**: a Pandoran Guard spearman who levels with you and returns 25 s after dying.
- **World**: a 200×200-tile procedural zone (forests, lakes, roads, bridges), camp in the centre, monsters get stronger with distance, champion packs, automap with fog of war.
- **Loot (minimal)**: gold and potions. Itemization comes later.

## Art
Everything is drawn with placeholder art in a SoM-like style. To use real sprites, see `assets/sprites/README.md` — drop in a sheet + small JSON and that unit switches over automatically.

## Code map
| File | Purpose |
|---|---|
| `scripts/skill_db.gd` | All Necromancer skill data & formulas (tune balance here) |
| `scripts/skills.gd` | What each skill does when cast |
| `scripts/creature_db.gd` | Monster & mercenary stats |
| `scripts/player.gd` | Necromancer: input, stats, leveling |
| `scripts/creature.gd` | AI for monsters, minions, merc |
| `scripts/unit.gd` | Shared health/damage/curses/poison/movement + placeholder art |
| `scripts/world.gd` | Map generation, collision, pathfinding, bone walls, automap |
| `scripts/ui/hud.gd` | Orbs, skill bar, skill tree, character screen, automap |

## Tests
`godot --headless --path . res://tests/smoke_test.tscn` — boots the game, levels to 30, learns and casts every skill, checks minions, death and respawn.
