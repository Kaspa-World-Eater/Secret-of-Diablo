#!/bin/bash
# Per-skill check for one order: each skill alone at level 10 on a level-20 pilgrim, cast at six tireless creatures
# for 8 s (same seed every run). Prints: skill | script errors | damage per second.
#   tools/survey.sh CLASS OUT.txt
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/opt/godot/Godot_v4.7.2-stable_linux.x86_64}
CLS=$1; OUT=${2:-/tmp/survey_$1.txt}; : > "$OUT"
for id in $(python3 -c "import json;[print(x['id']) for x in json.load(open('data/skills.json'))['skills'] if x['class']=='$CLS']"); do
  log=$(timeout 90 "$GODOT" --headless --path . --fixed-fps 30 --quit-after 100000 -- --seed=11 --zone=fen --new --cls=$CLS --lvl=20 --learn=$id:10 --autocast=$id --arena=6 --arena_kind=hollow --arena_t=8 2>&1 < /dev/null)
  errs=$(echo "$log" | grep -cE "SCRIPT ERROR")
  dps=$(echo "$log" | grep -oE "^BAL [^ ]+ dps [0-9.]+" | awk '{print $4}')
  echo "$id | errors $errs | dps ${dps:-none}" >> "$OUT"
done
cat "$OUT"
