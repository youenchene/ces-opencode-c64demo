# docs/opencode — the live presentation

Everything needed to present **opencode** at Codeurs en Seine 2026 (Rouen, Kindarena, 19 November 2026)
by having it edit this C64 demo live, with a fast model, while the audience watches.

| File | Content |
|---|---|
| [scenario.md](scenario.md) | The stage script, one act per opencode feature (dashboard, models, subagents, fork, MCP, compaction) |
| [setup.md](setup.md) | Before the talk: model, opencode config, key cheat sheet, screen layout, git safety net, real C64 |
| [rehearsal.md](rehearsal.md) | Timing sheet to fill in during rehearsals (one line per prompt per run) |
| [features-to-try.md](features-to-try.md) | opencode features not used yet that would help this talk (undo, warming, commands, images, agents, stats…) |

## Principles

1. **Every live prompt must succeed in under ~30 s** (model answer + `make run`). If a rehearsal shows a
   step takes longer or fails more than once in five tries, cut it or prepare it on a branch.
2. **Tier A effects only, live** (see `docs/08-effects-library.md`). Tier B effects are shown from
   prepared branches; Tier C never live.
3. **Never touch the timing-critical code live** (`irq_bars1/2`, cycle-counted loops).
4. **One known-good state per step**: branches `stage/step-N` (see setup.md), so any failure is one
   `git checkout` away from being fixed, and the show goes on.
5. The real C64 runs the **pre-built** demo the whole time. The live edits are shown in VICE; the final
   version goes to the real machine only at the end, if there is time.
