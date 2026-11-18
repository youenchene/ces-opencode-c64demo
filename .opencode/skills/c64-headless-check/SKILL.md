---
name: c64-headless-check
description: Use when asked to verify the C64 demo, check a demo change headlessly, or inspect a VICE capture for raster or text regressions.
---

# Verify D07 without opening a window

1. Run `make` from the repo root. Stop on a build failure and report the first
   useful diagnostic. Surface warnings rather than calling the build clean.
2. Run `make shots` and inspect the `opencode.png` section of its output or
   `build/shots/opencode.png`. Confirm the screenshot is new: the target can
   leave a previous capture in place when VICE fails. If no fresh demo capture
   was produced, report the visual check as blocked. Automated VICE runs use
   `-console`; a check is not a request for `make run`.
3. Check that D07 shows the logo and Rouen skyline, with a scroller row. In the
   summary, each copper-bar scanline should have `fg=0` (one colour across the
   line), and rows expected to show text should have foreground pixels. A
   single screenshot is not evidence of smooth motion.
4. For a timing-sensitive change, check `build/opencode.lst` for page
   crossings in the affected code and indexed tables. Report build, capture,
   and timing findings separately; PAL hardware timing still needs a real C64.
