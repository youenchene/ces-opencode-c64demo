# Scenario — "opencode codes a C64 demo, live"

Target: **~20 minutes** of live demo. The C64 demo is the excuse; what the audience should remember are
the opencode features used day to day: **dashboard/context**, **model selection**, **subagents**,
**fork**, **MCP**, **compaction**. Each act shows one of them with a visible result on the C64 screen.

Keys below are the defaults (leader = `Ctrl+X`, written `<leader>`); check them against your
`~/.config/opencode/cli.json` and the cheat sheet in `setup.md`. Times are budgets: confirm them in
`rehearsal.md`. Prompts are in English; write the French version beforehand if you prefer it on stage.

Fallback for any act: `git checkout stage/step-N -- src/main.asm && make run` (see `setup.md`).

---

## Act 0 — Cold open (1 min, no opencode)

The real C64 runs the pre-built demo (Kung Fu Flash): Codeurs en Seine logo, Rouen skyline, Teh Disco.
*"Everything you see was written in 6502 assembly by an AI agent. Let's change it live."*

## Act 1 — The dashboard: what the agent knows (2 min) · *sidebar, context, model info*

| | |
|---|---|
| Do | `opencode` in the repo. Show the **sidebar** (`<leader>b`): model, context used, cost. `<leader>s` for status (MCP servers, providers). |
| Prompt | `What is this repo and how do I check a change? 5 lines.` |
| Expected | Answer built from `AGENTS.md` (ACME, PAL, `make`, `make run`, `make shots`). No edits. |
| Show | The context counter already shows `AGENTS.md` loaded: *"this file is how you brief an agent"*. |
| Bonus | `/btw how many raster lines does a PAL C64 have?` — answered aside, not added to the conversation. |

## Act 2 — Fast model for fast edits (2 min) · *model selection*

| | |
|---|---|
| Do | `<leader>m` (or `/models`): pick the **fast model**. Point at it in the sidebar. |
| Prompt | `Change the scroller text to greet the Codeurs en Seine 2026 audience in Rouen, then run make.` |
| Expected | `scroll_text` edited (`!scr`, no `@`), `make` clean. |
| Show | `make run` → VICE, bottom row. Show elapsed time and cost in the sidebar. |
| Fallback | `stage/step-2` |

## Act 3 — Subagents in parallel (3 min) · *subagents*

| | |
|---|---|
| Prompt | `Use explore subagents in parallel: one finds the beat-flash example (A8) in docs/examples, one finds the sine-bars example (A3). Then integrate the beat flash into src/main.asm and run make.` |
| Expected | Two child sessions (read-only) report back; the main agent edits `irq_bottom`/main loop. |
| Show | While they run, browse the children (`↓` subagent picker, `←`/`→` between children, `↑` back to parent). Then `make run` with sound: border flashes on the music. |
| Talking point | Children have **fresh context**: the parent's context stays small (sidebar). |
| Fallback | `stage/step-3` |

## Act 4 — Fork: try another idea without losing this one (3 min) · *fork*

| | |
|---|---|
| Do | On the Act 3 answer, **Fork session from message** (palette `Ctrl+P` → "Fork"). |
| Prompt (in the fork) | `Instead of the flash, make the copper bars red and gold like the Normandy flag and move them on a sine (A3).` |
| Show | `make run`. Then go back to the original session (`Ctrl+Tab`): the conversation there is intact. |
| Important | A fork splits the **conversation**, not the files: both sessions share the working tree. Either commit before forking and compare with `git diff`, or move the fork to its own worktree (palette → "Move session" → new worktree) — **rehearse this**. |
| Fallback | `stage/step-4` |

## Act 5 — MCP: the agent drives other tools (2 min) · *MCP*

| | |
|---|---|
| Prompt | `Open docs/effects.html in the browser preview and tell me which Tier A effect would look best on the Rouen skyline.` |
| Expected | The agent starts a local server and calls the **baton** MCP tool `open_browser_preview`; the catalogue (GIFs + animated previews) appears beside the terminal. |
| Show | `/mcps` (or `<leader>s`) lists connected servers. The page is the visual library the agent itself generated. |
| Upgrade | A small **VICE MCP** (load PRG, screenshot, read memory via `x64sc -remotemonitor`) would let the agent *look at* the C64 screen itself — see `features-to-try.md`. |

## Act 6 — Compaction: long sessions keep going (2 min) · *compact*

| | |
|---|---|
| Do | Show the context gauge in the sidebar after five acts. `<leader>c` to **compact**. Show the summary (objective, decisions, files). |
| Prompt | `Continue: add the typer line "> can you run on a C64?" answered "  you're looking at it."` |
| Expected | Works right after compaction: the summary kept what matters (`typer_text`, control bytes, 13-row limit). |
| Show | Context gauge dropped; `make run`, wait for the opencode part. |
| Fallback | `stage/step-6` |

## Act 7 — Something bigger, prepared (2 min)

Not prompted live. `git diff stage/step-6 stage/step-7 --stat`, then `make run`: a Tier B effect
(suggested: B10 DYCP scroller, or B17 open border + B5 sprite letters spelling OPENCODE).
Show the session that produced it (`<leader>l`, session list) and its **timeline** (`<leader>g`).

## Act 8 — Back to the real machine (1 min, optional)

`make d64`, copy to the Kung Fu Flash SD, run on the C64. If short on time, skip: the C64 keeps running
the pre-built version.

## Closing line

*"64 KB, 1 MHz, and an agent that read the manual."*

---

## Feature → act map

| Feature | Act | Visible proof |
|---|---|---|
| Sidebar / context / cost | 1, 2, 6 | Context gauge and cost change on screen |
| Model selection | 2 (and 7: stronger model for big work) | Model name in the sidebar |
| Subagents | 3 | Child sessions, parent context stays small |
| Fork | 4 | Two sessions, two variants |
| MCP | 5 | Browser pane opened by the agent |
| Compaction | 6 | Context drops, work continues |
