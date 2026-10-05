// tools/zone_export/hook.js -- spliced inside the game's closure by build.sh (after every zz_ file), so it reaches the
// generators, the world drawers and their state. window.__zx.zone(id, seed) generates a zone exactly as a new game at
// that seed would (ZONE_GEN through enterZone, then one full draw pass so the lazily laid pieces -- props, landmarks,
// litter, decor -- exist) and returns it in the Godot build's zone format (data/zones/<id>_s<seed>.json, read by
// world/zone.gd, world/objects/* and core/main.gd). The sprites are recorded from the draw pass itself: every image the
// world drawers put on the canvas that is one of the painted pieces (W55 frames, prop frames, object sprites) becomes
// an entry with its key, foot point in tiles, depth and flip. Procedural pieces (palisade stakes, reeds, flames) are
// left to the Godot side, as before.
{
  const ZX = {};
  const r3 = v => Math.round(v * 1000) / 1000;
  ZX.rle = arr => { const out = []; let v = arr[0], n = 0; for (const a of arr) { if (a === v) n++; else { out.push(v, n); v = a; n = 1; } } out.push(v, n); return out; };
  ZX.enter = (id, seed) => { G.seed = seed; G.zones = {}; G.propsZone = null; enterZone(id); return G.zone; };

  // the wall builders per wall theme, as the Godot loader reads them (world/zone.gd _walls)
  const WALL_INFO = (wt) => {
    const fen = wt === 'fen', dung = { barrow: ['tx_barrow', 76, 'tx_top_grass'], bone: ['tx_bone', 88, 'tx_top_stone'], crypt: ['tx_crypt', 88, 'tx_top_stone'] }[wt];
    const cliff = { builder: 'cliff', wtexFace: fen ? 'tx_cliff_fen' : 'tx_cliff', wtexTop: fen ? 'tx_top_moss' : 'tx_top_grass', height: 64, cutHeight: 12 };
    return {
      3: { builder: 'rock', sprite: (fen ? 'rkf' : 'rk') + '{0..3} by hash(11x,5y)' }, 5: cliff,
      7: dung ? { builder: 'dungeon_wall:' + wt, wtexFace: dung[0], wtexTop: dung[2], height: dung[1], cutHeight: 12 } : cliff,
      8: { builder: 'fog', procedural: true, note: 'vertical translucent strands (vector)' },
      9: { builder: 'pillar', sprite: (wt === 'moor' || wt === 'fen' ? 'plo' : wt === 'bone' || wt === 'barrow' ? 'plw' : 'plc') + '{0..2} by hash(3x,7y)' },
      10: { builder: 'palisade', procedural: true, height: '30..40 per stake', note: 'sharpened log stakes, rope lashing, odd skull; no image asset' },
      15: { builder: 'ruin', wtexFace: 'tx_ruin', wtexTop: 'tx_top_stone', height: 'per cell: 30 + 11*floor(hash(3x,5y)*4) (+18 for the broken top)', cutHeight: 12 },
    };
  };

  // every painted piece's canvas -> what it is
  function pieceMap(z) {
    const M = new Map(), W = window.__w55;
    if (W) for (const k in W.W55) for (const fl of [false, true]) { const fr = W.frameOf(k, fl); if (fr && !M.has(fr.c)) M.set(fr.c, { key: k, set: 'w55', flip: fl, ox: fr.ox, oy: fr.oy }); }
    const kinds = {}; if (W) for (const k in W.W55) { const a = W.W55[k]; if (a.kind === 'prop') (kinds[a.prop] = kinds[a.prop] || []).push(k); }
    for (const kind in kinds) for (let v = 0; v < 8; v++) {
      let fr; try { fr = ztPropFrame(kind, v); } catch (e) { fr = null; } if (!fr) continue;
      const k = kinds[kind][v % kinds[kind].length];
      if (!M.has(fr.c)) M.set(fr.c, { key: k, set: 'w55', flip: false, ox: fr.ox, oy: fr.oy, prop: true });
      if (fr.f && fr.f !== fr.c && !M.has(fr.f)) M.set(fr.f, { key: k, set: 'w55', flip: true, ox: fr.w - 1 - fr.ox, oy: fr.oy, prop: true });
    }
    for (const o of z.objects) { let s = null; try { s = ztObjSprite(o); } catch (e) { } if (s && s._w55 && !M.has(s.c)) { const fr = W && W.frameOf(s._w55, false); M.set(s.c, { key: s._w55, set: 'w55', flip: false, ox: fr ? fr.ox : s.w / 2, oy: fr ? fr.oy : s.h - 3, obj: true }); } }
    return M;
  }

  // one draw pass over the whole zone with the drawing recorded
  function record(z) {
    const M = pieceMap(z), out = [];
    const saved = { W, H, cx: cam.x, cy: cam.y, onScreen, visibleRange, sin: Math.sin, dead: P.dead, time: G.time };
    W = 1e7; H = 1e7; cam.x = -(z.h * TW / 2) - 400; cam.y = -400;
    onScreen = () => true; visibleRange = () => ({ x0: 0, y0: 0, x1: z.w - 1, y1: z.h - 1 });
    P.dead = true; Math.sin = () => 0;   // no sway, no hero-shaped holes: each piece is drawn whole, as itself
    const o0 = iso(0, 0), ox_ = iso(1, 0), oy_ = iso(0, 1);
    const ax = ox_.sx - o0.sx, ay = ox_.sy - o0.sy, bx = oy_.sx - o0.sx, by = oy_.sy - o0.sy, det = ax * by - ay * bx;
    const toTile = (sx, sy) => { const u = sx - o0.sx, v = sy - o0.sy; return [(u * by - v * bx) / det, (ax * v - ay * u) / det]; };
    let cur = null;
    const di = ctx.drawImage;
    ctx.drawImage = function (img, a1, a2, a3, a4) {
      const m = cur && M.get(img);
      if (m && arguments.length <= 5) {
        const sc = arguments.length === 5 ? a3 / img.width : 1, [x, y] = toTile(a1 + m.ox * sc, a2 + m.oy * sc);
        out.push({ key: m.key, set: m.set, x: r3(x), y: r3(y), flip: m.flip, scale: r3(sc), d: r3(cur.d), src: cur.src, item: cur.item, tile: cur.tile, m });
      }
      return di.apply(this, arguments);
    };
    try {
      const list = [];
      renderWorld(list);
      for (const e of list) { const t = Math.round(e.d - 1); cur = { d: e.d, src: 'world', item: 'world' }; try { e.f(); } catch (err) { } }
      // trees and walls carry their tile
      for (const s of out) if (s.src === 'world') { s.tile = [Math.floor(s.x), Math.floor(s.y)]; s.item = /^(sp_|tr|tree)/.test(s.key) || (W55of(s.key) || {}).kind === 'tree' ? 'tree' : 'wall'; }
      ensureProps();
      (G.props16 || []).forEach((o, i) => { cur = { d: o.x + o.y - (o.kind === 'lily' || o.kind === 'bones' ? 0.8 : 0), src: 'props', item: 'prop:' + i, i }; try { drawProp(o); } catch (err) { } });
      z.objects.forEach((o, i) => {
        if (o.type === 'altar' || o.type === 'statue') return;
        cur = { d: o.x + o.y, src: 'objects', item: 'object:' + i, i };
        let s = null; try { s = ztObjSprite(o); } catch (err) { }
        if (s) try { drawSpr(s, o.x, o.y, 1, false); } catch (err) { }
      });
    } finally {
      ctx.drawImage = di; W = saved.W; H = saved.H; cam.x = saved.cx; cam.y = saved.cy; onScreen = saved.onScreen; visibleRange = saved.visibleRange;
      Math.sin = saved.sin; P.dead = saved.dead; G.time = saved.time;
    }
    return out;
  }
  const W55of = k => window.__w55 && window.__w55.W55[k];

  // the lights the world holds (lanterns, flames on props, landmark candles, camp fires), recorded from addLights16
  function lights(z) {
    const out = [], saved = { onScreen, fl: fireLight37, raw: addLightRaw, dead: P.dead, cx: cam.x, cy: cam.y };
    cam.x = 0; cam.y = 0; const o0 = iso(0, 0), ox_ = iso(1, 0), oy_ = iso(0, 1);
    const ax = ox_.sx - o0.sx, ay = ox_.sy - o0.sy, bx = oy_.sx - o0.sx, by = oy_.sy - o0.sy, det = ax * by - ay * bx;
    const toTile = (sx, sy) => { const u = sx - o0.sx, v = sy - o0.sy; return [(u * by - v * bx) / det, (ax * v - ay * u) / det]; };
    onScreen = () => true; P.dead = true; let src = '';
    fireLight37 = function (zz, x, y, R, rgb, a, fh, dx, kind) { out.push({ type: 'fire', kind, x: r3(x), y: r3(y), radius: r3(R), rgb, a: r3(a), heightPx: r3(fh), dxPx: r3(dx) }); };
    addLightRaw = function (sx, sy, r, rgb, a) { const [x, y] = toTile(sx, sy); out.push({ type: 'raw', x: r3(x), y: r3(y), radiusPx: r3(r), rgb, a: r3(a), screen: true, source: src }); };
    const dk = G.time; try { G.time = 0; addLights16(z); } catch (e) { } finally { onScreen = saved.onScreen; fireLight37 = saved.fl; addLightRaw = saved.raw; P.dead = saved.dead; cam.x = saved.cx; cam.y = saved.cy; G.time = dk; }
    return out;
  }

  // the ground litter (zz_zz_world77): small painted still-lifes, the images once, then where each lies
  function scatter(z) {
    const W77 = window.__world77; if (!W77) return {};
    const L = W77.lay(z); if (!L.land) return {};
    const ids = new Map(), sprites = [], items = [];
    const png = c => c.toDataURL('image/png');
    for (const arr of L.b.values()) for (const o of arr) {
      let id = ids.get(o.sp);
      if (id == null) { id = sprites.length; ids.set(o.sp, id); const fr = o.sp.sway ? o.sp.fr : [o.sp]; sprites.push({ id, w: o.sp.w, h: o.sp.h, sway: !!o.sp.sway, frames: fr.map(f => png(f.c)) }); }
      items.push([r3(o.x), r3(o.y), id, o.flip ? 1 : 0]);
    }
    return { land: L.land, grain: 2, sprites, items };
  }

  // the ambient light through the day, every 1/24 of it
  function ambient(z) {
    const rows = [], saved = G.clock; let out = false; try { out = isOutdoor(z); } catch (e) { }
    const len = (typeof DAY !== 'undefined' && DAY.len) || 600;
    for (let i = 0; i < 24; i++) {
      G.clock = (i / 24) * len;
      let rgb = [0, 0, 0], dk = 0; try { rgb = ambient37(z); dk = out ? dayK() : 0; } catch (e) { }
      rows.push({ phase: r3(i / 24), dayK: r3(dk), rgb });
    }
    G.clock = saved;
    return { outdoor: out, dark: z.dark, dayLengthS: len, byPhase: rows };
  }

  const plain = o => { const r = {}; for (const k in o) { const v = o[k]; if (v == null || typeof v === 'function') continue; if (typeof v !== 'object') r[k] = typeof v === 'number' ? r3(v) : v; else if (Array.isArray(v) && v.every(e => e == null || typeof e !== 'object')) r[k] = v; } return r; };

  ZX.zone = (id, seed, opts = {}) => {
    const z = ZX.enter(id, seed);
    const spr = record(z);                       // also lays the props, the litter, the landmarks
    const W = z.w, H = z.h;
    // where each object, prop, decor and landmark was drawn (index into sprites)
    const sprites = spr.map(({ m, ...s }) => s);
    const byItem = {}; sprites.forEach((s, i) => { if (s.item) (byItem[s.item] = byItem[s.item] || []).push(i); });
    let wt = 'moor'; try { wt = ztWallTheme(z); } catch (e) { }
    // decor (zz_zz_decor66) and landmarks (zz_landmarks55), placed by their own rules
    const decor = []; try { (window.__decor66.place(z) || []).forEach((o, i) => { const si = sprites.length; sprites.push({ key: o.k, set: 'decor', x: r3(o.x), y: r3(o.y), flip: !!o.flip, scale: 1, d: r3(o.x + o.y - 0.3), src: 'decor', item: 'decor:' + i }); decor.push({ i, key: o.k, x: r3(o.x), y: r3(o.y), flip: !!o.flip, fire: !!o.fire, sprites: [si] }); }); } catch (e) { }
    const landmarks = []; (z._lm55 || []).forEach((o, i) => { const si = sprites.length; sprites.push({ key: 'lm_' + o.d.id, set: 'landmark', x: r3(o.x0 + o.fw / 2), y: r3(o.y0 + o.fh / 2), flip: false, scale: 1, d: r3(o.x0 + o.y0 + o.fw + o.fh - 1.5), src: 'statues', item: 'landmark:' + i }); landmarks.push({ i, id: o.d.id, key: 'lm_' + o.d.id, name: o.d.name, inscription: o.d.inscription, x0: o.x0, y0: o.y0, fw: o.fw, fh: o.fh, cx: o.cx, cy: o.cy, foot: o.d.foot, lights: o.d.lights || [], sprites: [si] }); });
    // the grid, after the draw pass (the landmarks clear their footprints as they are laid)
    const t = Array.from(z.t);
    // a landmark stands on its footprint: those tiles are solid (rock), as the first exporter made them
    const lmRocks = []; for (const o of (z._lm55 || [])) for (let y = o.y0; y < o.y0 + o.fh; y++) for (let x = o.x0; x < o.x0 + o.fw; x++) if (x >= 0 && y >= 0 && x < W && y < H) { t[y * W + x] = 3; lmRocks.push([x, y]); }
    const cells = []; const TALLW = { 5: 1, 7: 1, 10: 1, 15: 1 };
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const v = t[y * W + x]; if (!TALLW[v]) continue;
      let edge = false; for (let j = -1; j <= 1 && !edge; j++) for (let i = -1; i <= 1; i++) { const q = z.get(x + i, y + j); if (q == null) continue; if (SOLID[q] === 0 || q === T.FOG) { edge = true; break; } }
      const info = WALL_INFO(wt)[v]; cells.push([x, y, v, edge ? 1 : 0, v === 10 ? 0 : v === 15 ? 30 + 11 * Math.floor(hash(3 * x, 5 * y) * 4) : info.height]);
    }
    const cls = []; for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) cls.push(ztClassOf(z, x, y) | 0);
    const texKeys = { 1: 'main', 2: 'main', 3: 'dirt', 4: 'mud', 5: 'road', 6: 'flags', 7: 'water', 8: 'bog', 9: 'shallow', 10: 'shallow', 11: 'crypt', 12: 'barrow', 13: 'bone', 14: 'arena' };
    let land = 'moor'; try { land = (window.__g55 && window.__g55.landOf(z)) || z.theme; } catch (e) { }
    const objects = z.objects.map((o, i) => Object.assign(plain(o), { i, solid: false, sprites: byItem['object:' + i] || [] }));
    const props = (G.props16 || []).map((o, i) => ({ i, kind: o.kind, v: o.v, x: r3(o.x), y: r3(o.y), sprites: byItem['prop:' + i] || [] }));
    const monsters = z.monsters.map((m, i) => ({ i, kind: m.type, name: m.name || (m.b && m.b.name), spr: m.b && m.b.spr, ai: m.b && m.b.ai, level: m.mlvl, rank: m.rank, pack: m.pack, x: r3(m.x), y: r3(m.y), hp: Math.round(m.max || m.hp), r: m.r, mods: m.mods || [], fly: !!m.fly, boss: !!m.boss }));
    const packs = {}; for (const m of monsters) { if (!m.pack) continue; const p = packs[m.pack] || (packs[m.pack] = { id: m.pack, n: 0, x: 0, y: 0, kinds: {}, ranks: {} }); p.n++; p.x += m.x; p.y += m.y; p.kinds[m.kind] = (p.kinds[m.kind] || 0) + 1; p.ranks[m.rank] = (p.ranks[m.rank] || 0) + 1; }
    for (const k in packs) { packs[k].x = r3(packs[k].x / packs[k].n); packs[k].y = r3(packs[k].y / packs[k].n); }
    const idxOf = f => z.objects.map((o, i) => f(o) ? i : -1).filter(i => i >= 0);
    const lanterns = z.lanterns.map((l, idx) => ({ idx, name: l.name, x: l.x, y: l.y, object: z.objects.findIndex(o => o.type === 'lantern' && o.x === l.x && o.y === l.y) }));
    const markers = {
      start: z.start || null, townCenter: z.townCenter || null, safeCircle: z.qSafeC || null, caveOut: z.caveOut || null, camp: z.camp || null, herd: z._herd || null,
      bossRoom: z.bossRoom || null, boss: z.boss ? { x: r3(z.boss.x), y: r3(z.boss.y) } : null, bossSpot: z.bossSpot || null, lanterns,
      waystones: idxOf(o => o.q === 'wp'), chests: idxOf(o => o.type === 'chest'), shrines: idxOf(o => o.type === 'shrine'), altars: idxOf(o => o.type === 'altar'),
      statues: idxOf(o => o.type === 'statue'), npcs: idxOf(o => o.type === 'vendor' || o.q === 'npc'), questObjects: idxOf(o => o.type === 'qobj' && o.q !== 'npc' && o.q !== 'wp'),
      ruins: z.ruins || [], channels89: z._w89c ? (z._w89pts || []) : [],
    };
    const connections = z.objects.map((o, i) => o.type === 'portal' ? { to: o.to, toName: o.toName || o.name, name: o.name, x: o.x, y: o.y, spr: o.spr, object: i, arriveHereFrom: null } : null).filter(Boolean);
    let mlvl = null; try { mlvl = (typeof ZONE_MLVL !== 'undefined' && ZONE_MLVL[id]) || null; } catch (e) { }
    const res = {
      format: 'godmarrow-zone/1', id: z.id, name: z.name, act: (typeof zoneAct === 'function' ? zoneAct(z.id) : 1), kind: z.town ? 'town' : (z.outdoor === false ? 'dungeon' : 'wild'),
      outdoor: (() => { try { return isOutdoor(z); } catch (e) { return false; } })(), seed, zoneSeed: z.seed, theme: z.theme, land, wallTheme: wt, scatterLand: null, dark: z.dark, mlvl,
      grid: { w: W, h: H, order: 'row-major, index = y*w + x', encoding: 'rle [value, count, value, count, ...]', cells: ZX.rle(t) },
      ground: { land, texKeys, classes: ZX.rle(cls) },
      walls: { info: WALL_INFO(wt), cells },
      objects, props, decor, landmarks, zoneProps: [], markers, connections, arrive: z.arrive || {}, quests: [],
      landmarkFootprintRocks: lmRocks, monsters, packs: Object.values(packs), lights: lights(z), ambient: ambient(z), scatter: scatter(z), sprites, warnings: [],
    };
    res.scatterLand = res.scatter.land || null;
    return res;
  };
  try { window.__zx = ZX; } catch (e) { }
}
