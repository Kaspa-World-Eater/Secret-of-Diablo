<!-- Planning · updated 2026-09-29 · 624 words · source page #backlog -->
# 09 · Backlog and open questions

## Next up (agreed direction)

- **Hemomancer full redo** (after the PixelLab reset on Oct 28, or from a user reference). Brief in `claude/godmarrow-class-hemomancer.md` §7.

- **Cinematography, next candidates:** cool rim light on figures at the pool's edge; per-act colour scripts; boss arenas with their own practical lights; a cool rim on creatures facing the lantern (needs a sprite redraw hook); a black-silhouette pass on the bestiary.

- **From the game study, still open:** named synergies; relics that change how the world answers; monster affixes; accessibility options. (Built in v82: the wick, the finishing blow, the lantern keeping a little, drop sounds. Declined: gold replacement, a throwable light.)

- **Treasure chests** read large next to the hero: resize later ("we can deal with it later"). Their size also hid their loot until v91.

- **Channels (v89):** watch whether 2–4 lines per zone feels right; the count and lengths are easy to tune in `zz_zz_world89.js`.

- **The Codex fills in by discovery (for release):** every chapter is open for now, while we build. Later, chapters, paragraphs and relic entries unlock as the player finds them: meeting a hero's order, picking up a relic, reading an inscription, entering a land. Unfound entries show as blank or scratched-out pages. The text lives in `src/zz_zz_tome94_text.js` (generated from the codex page).

## Parked (the user's call)

- **The Hollow King:** zombie cow king mini-boss for the herd ring. Code `zz_zz_king68.js` (excluded), art `data_off/king.js`. The PixelLab art was cartoony; remake after the reset, perhaps from a Midjourney reference.

- **Ossuarch:** out of commission.

- **Ground tiles** (still the old painted ground).

- **Armor tiers** (front/back paired by file naming in the `ARMOR_x` folders). **Weapons** in hand (hands are free now).

## Known gaps

- Desktop and Android apps: builds since v61 load `data/*.js` beside the page; `mk_app.py` must include them. Steam Deck tarball not rebuilt since v0.54. No icon, signing or updater.

- Mobile speed measured only in emulation; confirm on a real phone.

- The dark circle under the hero reported after v75 could not be reproduced; v76 lengthened shadows. Ask for a screenshot if it's seen again.

- Shrine Keeper and Ossuarch sprites are below the standard; the Shrine Keeper still has "Sigil" text where the HUD says Omen, and bird-named skills (Crow's Heel, Raven Flurry) in a world with no animals.

- Acts II–V use the nearest Act I palettes.

## Open questions for the user

- The Empty Hand's two sky skills still share a wait (breaks no-cooldowns); make it a cost?

- Soul (Yh'Anuul) has no Herald now that the Long Exhale belongs to Breath.

- Should Major Arcana cost Minor points too (one currency)?

- Does the Empty Hand's glass feel right (pour 5% per common cast; run-back rates are guesses)?

- Grave Spirit: stop seeking (the straight-bone rule)?

- An ossuary of the Chapter (the Ossuary of Nine Stairs, the Ninth Stair, the lowest hall) as an Act II side area, and the Gilded Peak's ruin (the courtyard of glass, the empty sanctum): visitable, or backstory only? And do the Frigid Heights (Act IV) lose their Tibetan names too?

- The Marrow Pontiff asks the Ossuarch to kneel; the Wet Nurse offers to take the Hemomancer's scourge. Real choices?

- An Act V ending where the flesh grows a head, with the Hemomancer as its thought?

- World mirrors as terrain for the Mystic: every reflective prop, or only tagged ones?

- The Long Exhale as Breath's Herald: confirm. Fans as their own weapon bases?

- Godmarrow as an in-world word for what lives in the bones: confirm.

- Body board: tarot emblem art on Major Arcana nodes, faint organs behind them, road names on hover.
