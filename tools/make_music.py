"""Render the score into audio/music with the Forge's generator (tools/pixelforge, `pixelforge music`).

    python tools/make_music.py [--seconds 120] [--only a1_town,boss1] [--sheet audio/music/music_sheet.json]

Every cue the game can ask for (world/soundscape.gd _pick: a<act>_town / a<act>_wild / a<act>_deep, boss<act>, title)
as a seamless OGG loop (WAV when ffmpeg is missing; Godot plays both), plus music.json and a spectrogram PNG per cue
(the PNGs stay out of the repo). Seeds are the browser score's, so each place keeps the tune it had.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "pixelforge"))

from pixelforge import music  # noqa: E402

LENGTH = {"title": 124.0}
for _a in range(1, 6):
    LENGTH[f"boss{_a}"] = 96.0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=float, default=120.0)
    ap.add_argument("--only", default="")
    ap.add_argument("--sheet", default=str(ROOT / "audio" / "music" / "music_sheet.json"))
    ap.add_argument("--format", default="ogg", choices=["ogg", "wav", "both"])
    a = ap.parse_args()
    out = ROOT / "audio" / "music"
    keys = [k for k in a.only.split(",") if k] or list(music.CUES)
    sheet = a.sheet if Path(a.sheet).exists() else None
    if not Path(a.sheet).exists():
        music.write_sheet(a.sheet)
        print("wrote the editable sheet", a.sheet)
    for k in keys:
        r = music.make_music(k, out, seconds=LENGTH.get(k, a.seconds), sheet=sheet, fmt=a.format, log=print)
        for f in r["files"]:
            print(" ", Path(f).name, f"{Path(f).stat().st_size // 1024} KB")
        for n in r.get("notes", []):
            print("  note:", n)
    for p in out.glob("*.png"):
        p.unlink()
    print("MUSIC_DONE", len(keys))
    return 0


if __name__ == "__main__":
    sys.exit(main())
