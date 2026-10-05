<!-- Build · updated 2026-09-29 · 772 words · source page #tech -->
# 08 · Code, build, tests, publishing and apps

*All paths relative to `scratchpad/` (the session scratchpad: `/tmp/claude-0/-home-claude//scratchpad/`). The scratchpad does not survive forever; this page is how to rebuild context.*

## 1. Where the code lives

- **Source:** `triune_desktop/src/` (~150 files). `retired/`, `parked/`, `src_off/` keep files taken out; `src/_exclude.txt` lists files the build skips (currently the r3/r7 Hemomancers and `zz_zz_king68.js`).

- **Order:** base files from `a_head.html` to `e_ui.js` (`e_ui.js` closes the IIFE), then every `src/zz_*.js` sorted, `zz_polish.js` last.

- **Data files:** `triune_desktop/data/*.js` are loaded as `` tags and copied next to the output (heroes `hhd_*.js`, `w61.js`, `wtex.js`, `lanterns.js`, `decor66.js`). Parked data in `data_off/`.

- **The pattern: wrap, don't edit.** Later files reassign function declarations (`drawHero = function…`) and keep what they wrap. Game code is **not** global to `page.evaluate`; expose test hooks on `window`.

- **Test hooks:** `window.__spm` (G, P, SK, startGame, enterZone, castSkill, hurtMon, FATE, heroFrame…), plus `__body`, `__reading`, `__monkHD`, `__voice`, `__act3/4`, `__sand`, `__percls`, `__title54`, `__chain`, `__wscale`, `__kneeler`, and the v60+ hooks: `__plLamp`, `__lampW`, `__lampFoot`, `__lampRGB`, `__lampK`, `__lampMood`, `__dark64`, `__shadow70`, `__cine76` (with `FL.force` to hold a lightning flash and `dbg()`), `__world77`, `__perf74`, `__decor66`, `__mobai`.

- **Saves:** `spiritmancer.save.v2` (test character `spiritmancer.test`); options `triune.opts`, music `triune.music`, shared stash `triune.stash.v1`.

## 2. Build, test, publish

| Step | Command | Must print |
|---|---|---|
| Build | `cd triune_desktop && bash build_x.sh OUT.html` | `SYNTAX OK` |
| Smoke test | `cd spiritmancer && HTML=OUT.html node smoke32.js` | `ERRS none` |
| Walk/still shots | `/tmp/ossport/walk2.js` (env HTML, CLS, ZONE, DAYK, SEQ, W, H) | frames `g_###.png` |
| Phone perf | `perfm.js` (iPhone UA, 844×390, CPU throttle via RATE) | fps |
| Staged night scene | `cine.js` (monsters placed round the hero, forced lightning, low life) | stills |

Older harnesses (`rd_shots.js`, `touch53/54.js`, `mkcast.js`, `quests_test.js`, `ingame.js`, `sand_test.js`, `chain_test.js`, `kn_ingame.js`, `title_shot.js`, `phone_test.js`) live in `spiritmancer/` or `triune_desktop/`. `smoke_monk.js` and `yy_test.js` are stale.
- **Night:** `G.clock = DAY().len * 0.78` is night; `* 0.3` is day. The Moor's start area is the town; test monsters in `hollow_wood`, `fen` or `burnt_heath` (the camp's safe sweep kills spawns: `G.zone.qSafeC`).
- **Publish the web demo:** copy the build to `scratchpad/triune_demoM.html` and publish it with the Artifact tool to [https://claude.ai/artifact/5wHDVwSeGwtzpUqpLa59Bp](https://claude.ai/artifact/5wHDVwSeGwtzpUqpLa59Bp) (first publish needs `files` for each `data/*.js`; later publishes keep them unless changed).

## 3. The desktop app (Electron 38.1.0, hand-assembled)

- `resources/app/` holds `main.js`, `package.json`, `index.html` (the game), `fonts.css` + `fonts/` (offline). One window, no menu, F11/Alt+Enter full screen, size remembered, full screen under Steam.

- Build: `python3 app/mk_app.py  `. On the user's PC: `Downloads\Godmarrow\Godmarrow.exe`, launcher `Desktop\Godmarrow\Play Godmarrow.bat`; Steam Deck tarball `Downloads\Godmarrow-SteamDeck.tar.gz` (not rebuilt since v0.54).

- Update: only `resources/app/index.html` changes (commit it straight over; ~11 MB).

- **Known gap:** builds since v61 load `data/*.js` beside the page. `mk_app.py` must copy them too (unverified) before the next app update.

- Not done: custom icon, code signing, in-app updater.

## 4. The Android app

- `Godmarrow.apk`: one full-screen landscape WebView served from `https://godmarrow.local/` (real origin, saves persist). Built without Gradle: `bash android/build_apk.sh  ` (aapt2 → javac → d8 → zipalign → apksigner with `godmarrow.keystore`, password `godmarrow`; keep it so updates install over). On the PC: `Downloads\Godmarrow-Android\Godmarrow.apk`. Same data-files gap as the desktop app.

## 5. Where each system lives

| System | Files |
|---|---|
| Heroes (PixelLab) | `zz_hero_hemomancer_r8.js`, `zz_hero_animancer_r8.js` + `data/hhd_*.js`; hit anim on hurt `zz_zv61.js` |
| Other heroes | `zz_hero_monk_hd.js`, `zz_hero_ossumancer.js`, painters in `zs_heroes.js`, `zo_heroesB.js` |
| Floating lantern | `zz_zy_lanclip64.js` + `data/lanterns.js` |
| Lantern light, glow, perks | `zz_zw_lantern63.js` |
| Darkness layer, wisp look | `zz_zx_dark64.js` |
| Light map | `y_light21.js` (L37: `addLightRaw`, `quantLight37`, `figureShadows37`) |
| Per-land grade | `zz_grade55.js`, `zz_tune_v59.js` |
| Hero shadow | `zz_zz_shadow70.js` |
| Cinematic cues | `zz_zz_cine76.js` |
| Ground scatter, canopy | `zz_zz_world77.js` |
| Perf mode, no blob, open bosses | `zz_zz_perf74.js` |
| Atmosphere | `zz_atmos62.js` |
| Walls | `zz_walls63.js` + `data/wtex.js` |
| Decor, the herd, camps | `zz_zz_decor66.js` + `data/decor66.js` |
| Monster AI | `zz_mobai63.js`, `zz_zz_imps67.js` |
| Packs, poise | `zz_zv60.js` |
| The Hollow King (parked) | `zz_zz_king68.js` (excluded) + `data_off/king.js` |
| HUD | `zz_hud54.js`, `zz_ui_hud.js`, `zz_ui.js`, `zz_ui_desc.js` |
| Melee | `zz_melee_chain.js`, `zz_mech_heavy.js`, `zz_ossu_active_melee.js` |
| The Empty Hand | `zw_monk.js`, `zw_monk_ui.js`, `zz_monk_sand.js` |
| The Reading | `q_fate.js`, `qa_fate22.js`, `zz_fate_tune.js`, `zz_fate_zcap.js`, `zz_art_reading.js`, `zz_art_rd0_stranger.js` |
| Body board | `zz_arcana_web.js`, `zz_arcana_zbody.js`, `zz_arcana_monk.js`, `zz_arcana_percls.js` |
| Acts, quests, voice | `zz_act1_expand.js`, `zz_world_expand.js`, `zz_openness.js`, `zz_act2.js`–`zz_act5.js`, `zz_quests.js`, `zz_voice.js` |
| World scale | `zz_worldscale.js` (with `ZK` in `b_core.js`) |
| Title | `zp_title.js`, `zz_title54.js` |
| Input | `w_touch17.js`, `zz_touch53.js`, `zz_ux_touch54.js`, `x_pad20.js` |
| Tuning | `zz_progression.js`, `zz_tune_batch_e.js`, `zz_mech_*.js` |
