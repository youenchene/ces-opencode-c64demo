# Setup — before going on stage

## Model

- A **fast model** ("flash"-class): the whole point is no visible waiting. Pick it in rehearsal by
  timing the prompts in `scenario.md` (fill `rehearsal.md`), not by benchmarks.
- Fix the model in the project so it can't change by accident: `opencode.json` at the repo root with
  `"model": "<provider>/<model>"` (check the exact id with `opencode models`).
- Have a second provider configured as a backup in case the conference Wi-Fi blocks the first one,
  and a 4G/5G hotspot.

## opencode

- Start in the repo root so `AGENTS.md` is loaded: `cd opencode-c64 && opencode`.
- Large terminal font (the room is big), dark theme, hide anything not needed.
- Optional: a custom command for "build and check" so the audience sees one word instead of a long
  instruction (e.g. `.opencode/command/check.md` running `make && make shots`).
- Fresh session per rehearsal and for the show (old context changes the answers).

## Key cheat sheet (defaults, leader = Ctrl+X)

| Act | Action | Keys / command |
|---|---|---|
| 1 | Toggle sidebar (model, context, cost) | `<leader>b` |
| 1 | Status (providers, MCP) | `<leader>s` |
| 1 | Side question, not added to history | `/btw <question>` |
| 2 | Choose model / cycle recent / variants | `<leader>m` · `F2` · `Ctrl+T` |
| 3 | Subagent picker / next-previous child / parent | `↓` · `→` `←` · `↑` |
| 4 | Fork from a message | `Ctrl+P` → "Fork session from message" (no default key) |
| 4 | Switch session tab | `Ctrl+Tab` |
| 5 | MCP servers | `/mcps` |
| 6 | Compact | `<leader>c` |
| 7 | Session list / timeline | `<leader>l` · `<leader>g` |
| any | Undo / redo last answer | `<leader>u` · `<leader>r` |
| any | Shell without the model | `!make run` |
| any | Interrupt | `Esc` |

Bind fork to a key in `~/.config/opencode/cli.json` if you use it often (`"keybinds": { "session.fork": "<leader>f" }`,
check that the combination is free in https://opencode.ai/docs/cli/keybinds).

## Screen layout

- Left: opencode. Right: VICE (`make run`, PAL, 8580 SID, sound on through the room's audio).
- The real C64 on its own screen/capture, visible the whole time.
- Test the audio path: VICE → laptop → room sound, and C64 → room sound.

## Git safety net

Prepare one branch per act from the known-good demo, each containing the expected result of that act:

```sh
git tag stage-ready                       # the demo as it should be at Act 0
git switch -c stage/step-2 stage-ready    # apply + commit the Act 2 change, then
git switch -c stage/step-3                # Act 3 on top of 2, and so on until step-7
git switch main
```

On stage, work on a throwaway branch: `git switch -c live stage-ready`. Recover from any failure with
`git checkout stage/step-N -- src/main.asm && make run`. Reset for a new rehearsal with
`git switch -C live stage-ready`.

## Real C64

- `make clean && make && make d64`, copy `build/opencode.d64` (and the `.prg`) to the Kung Fu Flash SD.
- Test on the real machine the day before, PAL only (see `docs/07-real-hardware.md`).
- Backup: second SD card; laptop VICE fullscreen if the C64 fails.

## Day-of checklist

- [ ] `git status` clean, `stage-ready` and all `stage/step-*` branches present
- [ ] `make` clean, `make run` plays music and stays on the `ces` screen
- [ ] opencode starts on the right model, network OK (and hotspot ready)
- [ ] Fresh opencode session, font size set
- [ ] VICE window placed, sound tested in the room
- [ ] Real C64 running the pre-built demo, music audible
- [ ] Prompts printed / on a second screen
- [ ] Rights for the music confirmed (Teh Disco, Jammer) or tune replaced
