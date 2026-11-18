# opencode features worth trying

Checked against the opencode V2 docs (https://opencode.ai/docs/, November 2026). For each: what it is, why it
helps this talk, how to set it up, and whether it's worth showing on stage. Config snippets go in
`opencode.jsonc` at the repo root unless stated otherwise; opencode reloads config without a restart.

## Top picks for the talk

| # | Feature | Why here | Stage-worthy? |
|---|---|---|---|
| 1 | **Undo / redo with snapshots** | Safer and faster than `git checkout` when a live edit goes wrong | Yes: "the agent broke it, `/undo`, done" |
| 2 | **Warming** | Keeps the provider prompt cache warm while you talk between acts → faster first token | Invisible, but makes every act snappier |
| 3 | **Project command** (`/check`) | One short word runs the build and headless verification | Yes |
| 4 | **Image attachments** | Paste a VICE screenshot: "the bars flicker on line 3, fix it" | Yes, if the stage model takes images |
| 5 | **Project agent + skill for C64** | A `c64` agent with the fast model and the rules; a reviewer subagent that checks cycle counts | Yes (Act 3 variant) |
| 6 | **`opencode stats`** | End the talk with the real cost and token count of the session | Yes, closing slide |

## Details

### 1. Snapshots: `/undo`, `/redo`, revert to a message

Every model step is snapshotted (git repo required). `/undo` (`<leader>u`) restores the files changed by the
last answer and puts the prompt back in the composer; `/redo` (`<leader>r`) cancels. Select an older message →
**Revert** to go back several steps. Only files inside the session directory; not `build/` (ignored).
Keep the `stage/step-N` branches anyway: snapshots are a convenience, not a backup.

### 2. Warming

```jsonc
{ "warming": { "interval": "auto", "duration": "1 hour" } }
```

Sends a tiny keep-alive request before the prompt cache expires, while you are talking. Costs a few tokens per
interval; `"auto"` needs the model's `cache.ttl` to be known (otherwise use `"interval": "4 minutes"`).

### 3. Project command

Run `/check` from the repo. The [command](../../.opencode/commands/check.md) expands to a short
prompt that loads [`c64-headless-check`](../../.opencode/skills/c64-headless-check/SKILL.md). It
builds, checks a headless D07 capture, and reports what it saw without editing the demo or opening
VICE. Rehearse the runtime before using it live: `make shots` captures the examples too.

### 4. Image attachments

Drag or paste a PNG into the prompt (web/desktop), or attach a file. Pair with
`x64sc ... -exitscreenshot shot.png` (see `make shots`). Only with a model that accepts images.

### 5. Project agents and skills

`.opencode/agents/c64-reviewer.md` — a read-only subagent:

```md
---
description: Reviews 6502 changes for cycle counts, page crossings and AGENTS.md rules
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
---
Review the current diff of src/main.asm. Check: cycle counts in timed loops, page crossings in build/opencode.lst,
zero page usage, data placed after DATA_START, row 13 text-only. Report findings by severity.
```

The project already ships [`c64-effects`](../../.opencode/skills/c64-effects/SKILL.md). Try
`@c64-effects How would A1 change the copper bars on D07? Don't edit anything.` The skill looks up
the recipe and matching example, then explains the visible effect and the hook. To show automatic
skill selection, try the same question without the `@c64-effects` mention.

### 6. `opencode stats`

`opencode stats --cost --models --days 1` at the end of the talk: what the whole live session cost.

### 7. Permissions for the stage

Make risky actions ask instead of run, e.g. no pushes and no edits to generated files:

```jsonc
{
  "permissions": [
    { "action": "shell", "resource": "git push *", "effect": "deny" },
    { "action": "edit", "resource": "src/gfx/**", "effect": "deny" }
  ]
}
```

**Policies** go further for the event: `{ "policies": [{ "action": "provider.use", "resource": "<other>", "effect": "deny" }] }`
keeps only the stage provider selectable, so nobody switches to a slow model by mistake.

### 8. References (other repos as context)

```jsonc
{
  "references": {
    "leeloo": { "repository": "youenchene/leeloo_s_journey", "description": "C64 game by the same author: music player, SID pipeline, VICE test scripts" }
  }
}
```

The agent can read the Leeloo project (music player, py65 checks) without copying it here. Private repo: uses
your git credentials. Also works for a local copy of the Codebase64 wiki dump.

### 9. Steering and queueing

While the agent works, **Enter** steers it ("use the example file, don't rewrite it"); `<leader>Enter` queues the
next prompt. `!make run` runs a shell command directly, without the model. `@src/main.asm#120-160` attaches lines.

### 10. Timeline, export, prepared sessions

`<leader>g` shows the session timeline (good for Act 7). `opencode session export` / `import` lets you prepare the
"big change" session at home and bring it on stage.

### 11. Model variants

`Ctrl+T` cycles the model's variants (e.g. reasoning effort): low for quick edits, high for the Tier B work.

### 12. Web UI and app (`opencode pair`)

`opencode pair` prints a link and QR code to open the same server in a browser or the opencode app: a second
screen showing the session, or controlling it from a phone while standing away from the laptop. Local by default;
`--remote` exposes it through an encrypted tunnel (asks first). Rehearse on the venue network.

### 13. A VICE MCP server (to build)

Not an opencode feature but an MCP use: a small server wrapping VICE's remote monitor (`x64sc -remotemonitor`)
with tools `run_prg`, `screenshot`, `read_memory`, `set_breakpoint`. The agent could then check its own result
without `make shots`, and the audience sees it "look" at the C64. Add with `opencode mcp add vice ...`.

### Also available

- **`opencode run "<prompt>"`** for scripted checks (e.g. a pre-show smoke test).
- **Background tools** (`Ctrl+B`) to push a long command (like `make gifs`) to the background.
- **Compaction settings**: `agents.compaction.model` for a cheaper summariser, `compaction.buffer` to compact earlier.
- **ACP** to drive opencode from an editor (Zed and others); **plugins** for custom tools or TUI panels.
