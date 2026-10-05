# Godmarrow Godot port: architecture and rules for everyone working on it

Godot 4.7.2, GDScript, Compatibility renderer (OpenGL). Project root: `/tmp/gd/Godmarrow`. The web build is the reference:
`/tmp/ossport/x71.html` (page) and `/tmp/claude-0/-home-claude/97784205-80df-5ff9-af53-809f027ba14e/scratchpad/triune_desktop/src/*.js`
(source; files in `src/_exclude.txt` are not in the build; later `zz_*` files wrap earlier functions, the final behaviour is what counts).
**Read `/home/claude/wiki/14-mechanics-checklist.md` for your system first**: it lists every mechanic with numbers and source files.

## Hard rules of the game (never break)
No cooldowns (costs gate power, never timers). Melee costs poise, never mana. Stagger x1.2 both ways. No red light sources; the dark is blue-teal.
No glows or flashes on attacks and casts (no swing arcs, no comet trails, no glowing blood). Bosses never lock you in a room and don't heal when
left. Gold is the currency and drops silently. D2-scarce loot. No animals or animal words (no birds, crows, ravens, dogs, wolves, rats...).
Banned words in any text the player reads: cooldown, dps, proc, aggro, loot, buff, nerf, stun, lightning, mana, rot, cell, virus, DNA, organism,
biology. The goddess is the Bleeding Maiden (never "Weeping"). No "!" markers over NPCs. The Empty Hand's class name is "The Empty Hand".

## Units and space
- Positions are **tiles (yards)**, floats: `tp: Vector2`. Screen: `Iso.to_screen(tp)` = ((x-y)*72, (x+y)*36) Godot units; `Iso.to_tile()`.
  1 Godot unit = 1 screen px at 1920x1080; camera zoom 1 (the web's desktop view).
- Depth: the zone's `sorted` node is y-sorted; put standing things there with `position = Iso.to_screen(tp)` (feet). Flat ground things go in
  `zone.floor_layer` (z -50).
- Sprites: `Data.sprite_set(kind)` -> `SpriteSet` (exported atlases in `res://art/sprites/<kind>.png|json`), drawn with `AnimSprite`
  (`play(anim, restart, loop)`, `step(dt, speed)`, `view`, `face` ±1). Heroes have views down/front/side/back/up
  (`AnimSprite.hero_view(dir, face)`), monsters front/back (`AnimSprite.mon_view`). Atlas px = screen px (scale 1).
- World art from the first extraction: `Assets.tex(path)`, `Assets.piece(cat, key)` (`res://assets/assets.json`: world, trees, decor, lanterns, wtex, ground).

## Autoloads
- `Data`: `Data.table("skills"|"monsters"|"items"|"classes"|"progression"|"world")` (exported JSON, schema in `res://data/README` =
  `/tmp/gd/export/data/README.md`), `Data.zone(id, seed)`, `Data.sprite_set(kind)`.
- `Game`: run state: `Game.cls`, `Game.phase()` (0..1 of a 600 s day), `Game.hour_name()` day/dusk/night/dawn, `Game.hour_speed()`,
  `Game.day_k()`, `Game.hitstop(secs)`, `Game.seed_for(zone_id)`.
- `Bus`: signals `monster_killed(m)`, `hero_hit(amount)`, `hero_died`, `level_up(level)`, `say(text, secs)`, `loot_dropped(item)`,
  `gold_changed(total)`, `zone_entered(zone_id)`, `boss_woke(m)`, `boss_felled(m)`. Add signals here if you need them (additive only).
- `Settings`: damage_numbers, hit_flash, screen_shake, auto_attack, hold_heavy, music_vol, sfx_vol.

## Core classes (owned by the lead; extend only through the hooks named)
- `Zone` (`world/zone.gd`): `load_zone(id, seed)`; `d` (the raw export: see `/tmp/gd/export/zones/README.md`); `w,h`, `types`, `is_solid(t)`,
  `blocks_sight(t)`, `type_at(t)`, `move(p, v, r)` (slide on walls), `line_clear(a,b)`, `sight_clear(a,b)`, `path(a,b)` (AStarGrid2D);
  `sorted`, `floor_layer`; `objects` (export objects), `lanterns`, `connections`, `arrive`, `markers`; `hero_ref`.
- `Hero` (`entities/hero.gd`): `tp`, `st: HeroStats`, `skills: SkillBook`, `zone`, `face/view`, `spr`, `act` ("" when free), `invuln`,
  `radius`, `dead`; `walk_to(t)`, `mouse_tile()`, `monster_at_mouse()`, `spend_poise(n)`, `poise_hit(pd, from, heavy)`, `drink(i)`, `die()`,
  `revive(at)`, `_start_act(anim, secs)` (plays an action pose for secs), signals `stats_changed`, `died`.
- `HeroStats` (`core/hero_stats.gd`): level, xp, vit/ess/con (+ `e_vit()` etc. with items), `hp`, `res`, `poise`, `life_max()`, `res_max()`,
  `res_regen()`, `res_name()`, `armor()`, `poise_max()`, `skill_mult()`, `melee_mult()`, `cast_speed()`, `attack_speed()`, `move_speed()`,
  `resist(elem)`, `item(stat)` (equipment + `extra` dict for temporary bonuses), `inv: Inventory`, `skill_points`, `attr_points`,
  `hollow_tokens`, `arcana_points`, `kept`, `dim_wick`, `heal_pool`, `restore_pool`, `add_xp(n)`, `xp_to_next()`.
- `Monster` (`entities/monster.gd`): `tp, hp, hp_max, dmg (Vector2 min,max), speed, armor, xp, radius, level, rank, kind, ai, kd (monsters.json row),
  info (export row), pack, boss, dead, buried, flying, z_lift, face, view, spr`, poise/reel state (`reeling`, `after_reel`, `stun`, `root`,
  `slow`, `feared`, `confused`, `marked`, `dots`), `brain: Brain`; `roll_damage()`, `move_speed()`, `can_act()`, `step_toward(p, dt, spd)`,
  `look(dir)`, `add_dot(dps, secs, elem)`, `die(from)`, `hero()`. Groups: "monsters" (alive), "corpses".
- `Brain` (`entities/ai/brain.gd`): sleep/loiter/wake (packmates), attack tokens, the standard melee rhythm (chase, wind, strike, recover,
  gap), `_approach()` with pathing, `_circle()`. **AI kinds** subclass it in `entities/ai/ai_<ai>.gd` (the file name is the kind's `ai`:
  husk, flank, kiter, ghost, bomber, pyre, charger, burrow, flyer, shield, duelist, stalker, boss, herald). Override `think()`,
  `damage_taken_mult()`, `on_hit()`, `on_reel()`, `on_death()`.
- `Combat` (`core/combat.gd`): `hit_monster(m, dmg, elem, from, opts)` (opts: melee, heavy, poise, dot), `hit_hero(h, dmg, elem, from, opts)`,
  `monsters_in(zone, c, r)`, `nearest_monster(zone, c, r, need_sight)`.
- `Missile` (`entities/missile.gd`): `Missile.fire(zone, from, to, speed, dmg, elem, side "hero"|"monster", look)`; `on_hit` callable,
  `pierce`, `opts`, `height`, `col`. Group "allies" is what monster missiles and blows can also hit (minions): give allies `tp`, `radius`,
  `take_hit(dmg, elem, from)`.
- `Item`, `Inventory` (`items/`): see the files. Inventory API for the UI: `bag` [{item,pos}], `equip` {slot: Item}, `belt` [4 x {kind,n}],
  `gold`, `add(it)`, `remove(it)`, `equip_item(it)`, `unequip(slot)`, `move_to(it, pos)`, `item_at(pos)`, `pos_of(it)`, `can_equip(it, lvl, cls)`,
  `drink(i)`, `total(stat)`, `armor()`, signal `changed`.
- `SkillBook` (`skills/skill_book.gd`): `hard` {id: points}, `left`, `right`, `keys` {"q".."f": id}, `data` {id: skills.json row},
  `lvl(id)`, `growth(id)`, `cost(id)`, `num(id, part, j)` (sampled tooltip numbers), `can_learn(id)`, `learn(id)`, `use(id, at, target)`;
  a class overrides `_cast(id, at, target) -> bool`, `tick(dt)`, `absorb(d, elem)`, `on_weapon_hit(m, d)` in `skills/<cls>.gd`
  (`class_name` not needed; it is loaded by path).
- `Lights` (`core/lights.gd`): `Lights.radial(size)`, `Lights.pool(size)` (the stepped lantern pool), `Lights.flicker(parent, pos, col,
  energy, scale, shadows)`. `Fx` (`fx/fx.gd`): `Fx.blood(parent, pos, dir, n)`, `Fx.number(parent, pos, v)`.
- `core/main.gd` is the game scene (zone entry, gates, lantern-stones, death and the remnant, XP on kill). It calls, if the file exists,
  `load("res://items/loot.gd").on_kill(zone, m, hero)` on every kill, and `load("res://ui/hud.gd").new()` (a CanvasLayer with
  `bind(hero, zone)`, called on every zone entry). Other systems: make a `static func attach(main, zone, hero)` in your own file and say so in
  your report; the lead wires it into `main.gd`.

## Working rules for helpers
- Only create or edit files in your own area (listed in your task). If you need a change in a core file, keep it **additive** (a new
  function or signal), mark it with a comment `# (your area): why`, and list it in your report.
- Avoid `class_name` on new files unless you really need a global type (it forces an editor import that other helpers may be running at
  the same time); load scripts by path instead. If you add one, run `godot --headless --import --path .` once.
- Test headless: `/opt/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path /tmp/gd/Godmarrow --quit-after 900 -- --zone=moor --demo`
  (user args after `--`: `zone=<id>`, `cls=<class>`, `hour=<0..1>`, `demo` (auto-fight), `trace`). Grep the output for `SCRIPT ERROR`.
  Render frames: `/tmp/gd/shot.sh <name> <frames> --zone=fen --demo` (writes `/tmp/ossport/<name>.png`, the last frame, 1600x900;
  all frames in `/tmp/gd/mov_<name>/`). Look at your frames.
- Write player-facing text in the world's voice (Dark Souls: oblique, grave, plain), never a tutorial or wiki voice.
