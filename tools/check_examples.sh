#!/bin/zsh
# Headless smoke test of every example (make check-examples).
# Runs each build/examples/*.prg twice in VICE, 20 PAL frames apart, and reports:
#   blank  = screenshot has a single colour everywhere (nothing drawn)
#   static = both screenshots identical (no animation; fine for a few examples)
#   ok     = something drawn and it changes
# Exit code 1 if any example is blank. Shots go to build/check/.
cd "$(dirname "$0")/.."
O=build/check
mkdir -p $O
for p in build/examples/*.prg; do
  b=$(basename $p .prg)
  for c in 9000000 9393120; do
    x64sc -pal -default +sound -warp -autostartprgmode 1 -limitcycles $c \
      -exitscreenshot $O/${b}_$c.png -autostart $p >/dev/null 2>&1 &
  done
  while [ $(jobs -r | wc -l) -ge 10 ]; do sleep 0.2; done
done
wait
blank=0
for p in build/examples/*.prg; do
  b=$(basename $p .prg)
  a=$O/${b}_9000000.png; z=$O/${b}_9393120.png
  if [ ! -f $a ] || [ ! -f $z ]; then echo "missing $b"; blank=1; continue; fi
  n=$(python3 -I tools/pngsum.py $a | tail -n +2 | wc -l)
  if [ $n -le 1 ]; then state=blank; blank=1
  elif cmp -s $a $z; then state=static
  else state=ok; fi
  printf "%-8s %s\n" $state $b
done
exit $blank
