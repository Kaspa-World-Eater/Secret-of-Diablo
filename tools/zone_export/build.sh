#!/bin/bash
# tools/zone_export/build.sh OUT.html -- the browser build (web/triune_desktop, as build_x.sh makes it) with the zone
# exporter (hook.js) spliced inside the game's closure, where it can reach the generators and the world drawers.
# Windows (Git Bash) and Linux. Needs python.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; WEB="$HERE/../../web/triune_desktop"; OUT="$1"
PY=$(command -v python3 >/dev/null 2>&1 && python3 -c "" 2>/dev/null && echo python3 || echo python)
cd "$WEB"
LIST=$(sed -n 's/.*cat \(.*\) > triune.html.*/\1/p' build.sh)
cat $LIST > "$OUT"
PYTHONUTF8=1 "$PY" - "$OUT" "$HERE/hook.js" <<'PYEOF'
import glob, os, shutil, sys
out, hook = sys.argv[1], sys.argv[2]
s = open(out, encoding='utf-8').read()
ex = set(open('src/_exclude.txt').read().split()) if os.path.exists('src/_exclude.txt') else set()
fs = sorted(f for f in glob.glob('src/zz_*.js') if not f.endswith('zz_polish.js') and os.path.basename(f) not in ex) + ['src/zz_polish.js']
z = ''.join(open(f, encoding='utf-8').read() + '\n' for f in fs) + open(hook, encoding='utf-8').read() + '\n'
i = s.rfind('})();'); s = s[:i] + z + '\n' + s[i:]
ds = sorted(glob.glob('data/*.js'))
tags = ''.join('<script src="' + os.path.basename(d) + '"></script>' for d in ds); i = s.rfind('<script>'); s = s[:i] + tags + s[i:]
open(out, 'w', encoding='utf-8').write(s)
for d in ds: shutil.copy(d, os.path.join(os.path.dirname(os.path.abspath(out)), os.path.basename(d)))
print('built', out)
PYEOF
