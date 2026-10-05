extends Node
## Autoload "Bus": game-wide events, so systems stay decoupled.
signal monster_killed(m)
signal hero_hit(amount)
signal hero_died
signal level_up(level)
signal say(text, secs)
signal loot_dropped(item)
signal gold_changed(total)
signal zone_entered(zone_id)
signal boss_woke(m)
signal boss_felled(m)
signal herald_felled(m, god)   # (creature AI port): a god's Herald is unmade; the Arcana system grants its Major Arcanum
signal panel_requested(panel, who)   # (world objects): a townsfolk opens a panel: "vendor" | "smith" | "stash" | "journal"
signal quest_changed(id)             # (world objects): an vow was written or fulfilled (world/quests.gd)
