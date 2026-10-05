// node tools/zone_export/export.mjs [--seeds=N] [--first=S] [--zones=a,b] [--out=data/zones] [--workers=4] [--force]
// Builds the browser game with the exporter spliced in (build.sh), opens it in headless Chrome (cdp.mjs) and writes
// every Act I zone at N seeds (S, S+1, ...) to data/zones/<id>_s<seed>.json.gz (gzip), then rewrites data/zones/index.json so
// the game picks among all of them (core/game.gd seed_for). The static facts of each zone (act, kind, mlvl, links)
// are kept from the index already there.
import { open } from './cdp.mjs';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs'; import zlib from 'node:zlib'; import path from 'node:path'; import url from 'node:url';
const HERE = path.dirname(url.fileURLToPath(import.meta.url)), ROOT = path.resolve(HERE, '../..');
const arg = (k, d) => { const a = process.argv.find(a => a.startsWith('--' + k + '=')); return a ? a.split('=')[1] : d; };
const N = +arg('seeds', 24), FIRST = +arg('first', 1001), OUT = path.resolve(ROOT, arg('out', 'data/zones'));
const idxPath = path.join(OUT, 'index.json'), index = JSON.parse(fs.readFileSync(idxPath, 'utf8'));
const zones = arg('zones', '') ? arg('zones').split(',') : Object.keys(index.zones);
const tmp = path.join(process.env.TEMP || '/tmp', 'gm_zone_export'); fs.mkdirSync(tmp, { recursive: true });
const html = path.join(tmp, 'zx.html').split(path.sep).join('/');
execFileSync('bash', [path.join(HERE, 'build.sh').split(path.sep).join('/'), html], { stdio: 'inherit' });
const WORKERS = Math.max(1, +arg('workers', 4)), FORCE = process.argv.includes('--force');
const seeds = Array.from({ length: N }, (_, i) => FIRST + i);
const jobs = []; for (const id of zones) for (const seed of seeds) jobs.push([id, seed]);
const errs = [];
async function worker(w) {
  const b = await open('file:///' + html.replace(/^\//, ''), 9340 + w);
  await b.ev(`(()=>{ const S=window.__spm; S.G.pickCls='animancer'; S.startGame('export'); })()`);
  for (let job; (job = jobs.shift());) {
    const [id, seed] = job, info = index.zones[id], f = `${id}_s${seed}.json.gz`;
    if (!FORCE && fs.existsSync(path.join(OUT, f))) continue;
    const j = JSON.parse(await b.ev(`JSON.stringify(window.__zx.zone(${JSON.stringify(id)}, ${seed}))`));
    j.act = info.act; j.kind = info.kind; j.mlvl = info.mlvl;
    fs.writeFileSync(path.join(OUT, f), zlib.gzipSync(JSON.stringify(j), { level: 9 }));
    process.stdout.write(`[${w}] ${id} ${seed} ${j.grid.w}x${j.grid.h} sprites ${j.sprites.length} monsters ${j.monsters.length}
`);
  }
  errs.push(...b.logs.filter(l => /^EXC/.test(l))); b.close();
}
await Promise.all(Array.from({ length: WORKERS }, (_, w) => worker(w)));
for (const id of zones) { const info = index.zones[id]; info.seeds = seeds; info.files = seeds.map(s => `${id}_s${s}.json.gz`); }
index.generated = new Date().toISOString(); index.source = 'tools/zone_export (web/triune_desktop at ' + execFileSync('git', ['-C', ROOT, 'rev-parse', '--short', 'HEAD']).toString().trim() + ')'; index.seeds = seeds;
fs.writeFileSync(idxPath, JSON.stringify(index, null, 1));
if (errs.length) console.log(errs.slice(0, 5).join('\n'));
