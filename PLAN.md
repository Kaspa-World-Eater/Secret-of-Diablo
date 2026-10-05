# Secret of Diablo — Build Plan (handoff for local session)

A Secret of Mana–style action RPG rebuilt around Diablo 2 mechanics. Prototype phase: **no story, no quests** — the goal is a playable Necromancer.

## Decisions already made
| Topic | Decision |
|---|---|
| Engine | **Godot 4** (installed locally). GDScript. |
| Perspective | **Top-down, Secret of Mana style** (not isometric) |
| Art | Placeholder shapes/colored tiles for now; optionally swap in Secret of Mana sprites the user has locally. Keep art behind a simple sprite/animation layer so it's swappable. |
| Controls | **D2 mouse scheme**: left-click = move / attack target, right-click = cast the selected right skill, hotkeys F1–F8 to bind skills, Q/W-style potion belt (1–4), `A` stats, `T` skill tree, `I` inventory, `Tab` automap, Shift = attack in place. |
| Party | **Solo hero + one AI mercenary** (D2 hireling style) |
| Progression | **D2 leveling**: 5 stat points + 1 skill point per level; Str / Dex / Vit / Energy; skill prerequisites; synergies; skill levels raise damage/mana cost. |
| World | **Large, open D2-style zones** (big outdoor areas + dungeons), randomized layouts, fog of war, automap, waypoints/town portal later. |
| Scope now | Build the **Necromancer** class into a playable sandbox. |

## Milestone 1 — Playable Necromancer sandbox
1. **Project scaffold**: `project.godot`, main scene, input map (mouse + hotkeys), autoloads for game state / skill database.
2. **Player controller**: right-click/left-click per D2, click-to-move with `NavigationAgent2D`, target-under-cursor attack, HP/mana regen.
3. **Stats & leveling**: XP curve, level up gives 5 stat + 1 skill point, derived stats (life from Vit, mana from Energy, etc. using Necro D2 ratios).
4. **Large open zone**: procedural top-down map (e.g. 200×200 tiles) stitched from noise/chunks, collision, navigation mesh, fog of war, simple automap overlay.
5. **Enemies**: a few monster types (melee, ranged, fast), packs, spawn density like D2, XP rewards. **Enemies leave corpses** (critical for Necro skills), corpses are consumable.
6. **Necromancer skill trees** (data-driven, e.g. a `skills.json` or Resource files):
   - **Summoning**: Skeleton Mastery (passive), Raise Skeleton, Clay Golem, Golem Mastery, Raise Skeletal Mage, Blood Golem, Summon Resist, Iron Golem, Fire Golem, Revive.
   - **Poison & Bone**: Teeth, Bone Armor, Poison Dagger, Corpse Explosion, Bone Wall, Poison Explosion, Bone Spear, Bone Prison, Poison Nova, Bone Spirit.
   - ~~Curses~~ → replaced by **Bone Melee** (see below).
   - Use D2 prerequisites, required levels (1/6/12/18/24/30), and synergies (e.g. Bone Spear gets +% from Teeth, Bone Wall, Bone Prison, Bone Spirit).
   - Priority to implement first: Raise Skeleton, Skeleton Mastery, Clay Golem, Teeth, Bone Armor, Corpse Explosion, Bone Spear, Amplify Damage, Poison Nova, Raise Skeletal Mage. Remaining skills can be stubbed with data and filled in after.
7. **Minions**: skeletons/mages/golems with follow + engage AI, minion cap scales with skill level, minions level with skill.
8. **Mercenary**: hire one AI companion (start with a melee guard type); follow / engage / retreat states; gains XP; can be revived.
9. **UI**: life/mana orbs, XP bar, left/right skill slots + skill selection popup, hotkey binds, stat screen (`A`), skill tree screen (`T`) with three tabs and prerequisite lines, floating damage numbers, enemy health bar on hover.
10. **Loot (minimal)**: health/mana potion drops and a belt; gold. Full itemization (affixes, rarities, sockets) is a later milestone.

## Decisions since Milestone 1
- **Feel:** D2R pacing and weight; melee plays like Secret of Mana (stamina gauge, charge attacks, knockback, hit stun).
- **Every class gets a melee tree** (later). Each melee skill has its own charge attacks and style, bound to the skill.
- **Controls:** click-to-move plus controller support.
- **Necromancer:** keeps D2 Summoning and Poison & Bone; Curses replaced by a custom **Bone Melee** tree.
- **Light:** central system. Day/night cycle (20 min). A lantern carried by a small immortal, untargetable minion is your light; it can be planted and recalled.
- **No story yet** — building systems only.

## Milestone 2 — done
Bone Melee tree, SoM stamina/charge combat, day/night with darkness, lantern bearer, night-only Shades, controller support.

## Later milestones (not now)
- Itemization: inventory grid, affixes, magic/rare/set/unique, sockets & runewords, merc gear, **lantern items with light affixes**.
- Dungeons (always dark), light-reacting monster types (fear light, drawn to light, hidden objects revealed by light).
- Town hub: vendors, stash, merc hiring.
- More classes (SoM-flavored: Warrior with weapon-orb charged attacks, elemental-spirit Sorceress/Mystic).
- Difficulty tiers (Normal/Nightmare/Hell), acts themed after SoM regions, bosses.

## Notes
- Keep all skill/monster numbers in data files so balance can be tuned without code changes.
- Art is placeholder; Secret of Mana / Diablo 2 assets are copyrighted — fine for a private personal build, but use original assets before any public release.
- D2R is installed locally via Steam: use it as a reference for feel/numbers only.
