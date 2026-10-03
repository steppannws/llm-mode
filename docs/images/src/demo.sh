#!/usr/bin/env bash
# Builds docs/images/demo.gif: the vhs recording of demo.tape, framed like hero.png.
# Needs vhs, ffmpeg, Google Chrome. Run from the repo root.
set -euo pipefail
cd "$(dirname "$0")/../../.."

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT=build/demo
mkdir -p "$OUT"

vhs docs/images/src/demo.tape

python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER' EXIT
sleep 1
for layer in bg fg; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --default-background-color=00000000 \
    --window-size=1100,540 --screenshot="$PWD/$OUT/$layer.png" \
    "http://127.0.0.1:8765/docs/images/src/demo.html?layer=$layer" 2>/dev/null
done

# rounded-corner alpha mask for the 760x434 terminal
ffmpeg -loglevel error -y -f lavfi -i "color=white:s=760x434,format=gray" -vf \
  "geq=lum='if(gt(pow(max(0,max(11-X,X-748)),2)+pow(max(0,max(11-Y,Y-422)),2),121),0,255)'" \
  -frames:v 1 "$OUT/mask.png"

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 build/demo-term.mp4)
ffmpeg -loglevel error -y -loop 1 -t "$DUR" -i "$OUT/bg.png" -i build/demo-term.mp4 \
  -loop 1 -t "$DUR" -i "$OUT/mask.png" -loop 1 -t "$DUR" -i "$OUT/fg.png" -filter_complex "
  [1:v]scale=760:434:flags=lanczos,format=rgba[t];
  [2:v]format=gray[m];
  [0:v]format=rgba[b];
  [3:v]format=rgba[f];
  [t][m]alphamerge[tr];
  [b][tr]overlay=44:48:shortest=1:format=auto[a];
  [a][f]overlay=0:0:shortest=1:format=auto,fps=12,split[s0][s1];
  [s0]palettegen=max_colors=128:stats_mode=diff:reserve_transparent=1[p];
  [s1][p]paletteuse=dither=none:diff_mode=rectangle:alpha_threshold=128" \
  -loop 0 "$OUT/raw.gif"

# full-frame redraws from ffmpeg; gifsicle keeps only what changes between frames
gifsicle -O3 "$OUT/raw.gif" -o docs/images/demo.gif

ls -lh docs/images/demo.gif
