---
name: c64-effects
description: Use when asked to choose, explain, or apply a C64 effect from this repo's catalogue, including A/B/C recipes and existing D effects.
---

# Work with the C64 effects catalogue

1. Find the effect in `docs/08-effects-library.md`. A/B/C IDs are recipes; D IDs
   refer to effects already in the demo. For a recipe, zero-pad the ID (`A1` →
   `A01`) and read the matching `docs/examples/<ID>_*.asm`, including its
   `Limitations:` header. For a D effect, find its current hook in `src/main.asm`.
2. Explain what the audience will see, name the hook, and flag any example
   assumptions that don't hold in D07. If asked for advice or an explanation,
   stop there without editing.
3. For a live edit, stay with Tier A changes that fit existing hooks. If the
   requested change needs a new IRQ or cycle-counted changes, suggest a simpler
   variant or a prepared branch. Keep D07, the copper bars, and the scroller
   running. For a new demo effect, follow the stable D ID workflow in the
   catalogue; a tweak to an existing effect keeps its ID.
4. After editing, use `c64-headless-check` to verify the result. Open VICE
   with `make run` only if the user asks for a live preview.
