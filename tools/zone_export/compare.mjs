// node tools/zone_export/compare.mjs ZONE SEED [HOUR=0.3] [CLS=animancer] [OUT=docs/screens/compare]
// The same zone, seed, hour and order in the browser build (the reference) and in the Godot build, captured at
// 1600x900 and laid side by side: OUT/<zone>_s<seed>_h<hour>.png (browser left, Godot right). The seed must be one
// tools/zone_export/export.mjs wrote (data/zones/index.json). Godot: GODOT=path or the usual places.
import { open } from './cdp.mjs';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs'; import path from 'node:path'; import url from 'node:url';
const HERE = path.dirname(url.fileURLToPath(import.meta.url)), ROOT = path.resolve(HERE, '../..');
const [zone, seed, hour = '0.3', cls = 'animancer', outDir = 'docs/screens/compare'] = process.argv.slice(2);
const OUT = path.resolve(ROOT, outDir); fs.mkdirSync(OUT, { recursive: true });
const tmp = path.join(process.env.TEMP || '/tmp', 'gm_compare'); fs.mkdirSync(tmp, { recursive: true });
const html = path.join(tmp, 'zx.html').split(path.sep).join('/');
execFileSync('bash', [path.join(HERE, 'build.sh').split(path.sep).join('/'), html], { stdio: 'ignore' });
const web = path.join(tmp, 'web.png'), gd = path.join(tmp, 'godot.png');
const b = await open('file:///' + html.replace(/^\//, ''), 9334);
await b.ev(`(()=>{ const S=window.__spm; S.G.pickCls=${JSON.stringify(cls)}; S.startGame('compare'); })()`);
await b.ev(`(()=>{ const S=window.__spm; S.G.seed=${+seed}; S.G.zones={}; S.enterZone(${JSON.stringify(zone)}); S.G.clock=${+hour}*600; for (const k in (S.G.panels||{})) S.G.panels[k]=false; })()`);
await new Promise(r => setTimeout(r, 3000));
await b.shot(web); b.close();
const GODOT = process.env.GODOT || ['C:/Users/' + (process.env.USERNAME || '') + '/OneDrive/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe',
  'C:/Users/' + (process.env.USERNAME || '') + '/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe', '/opt/godot/Godot_v4.7.2-stable_linux.x86_64'].find(p => fs.existsSync(p));
try { execFileSync(GODOT, ['--path', ROOT, '--', `--zone=${zone}`, `--zseed=${seed}`, `--hour=${hour}`, `--cls=${cls}`, '--new', `--shot=${gd}`, '--shot_t=5'], { stdio: 'ignore', timeout: 120000 }); } catch (e) { }
const out = path.join(OUT, `${zone}_s${seed}_h${hour}.png`);
execFileSync('python', ['-c', `import sys
from PIL import Image
a=Image.open(sys.argv[1]).convert('RGB'); b=Image.open(sys.argv[2]).convert('RGB').resize(a.size)
c=Image.new('RGB',(a.width*2+8,a.height),(20,18,24)); c.paste(a,(0,0)); c.paste(b,(a.width+8,0)); c.save(sys.argv[3])`, web, gd, out]);
console.log(out);
