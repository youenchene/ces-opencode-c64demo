#!/usr/bin/env python3
"""Build docs/effects.html: a visual catalogue of every demo effect.

Usage: python3 tools/effects_page.py        (or: make effects-page)

- "In the demo" cards are parsed from the D-ID table in docs/08-effects-library.md
   and use real VICE captures from docs/img/effects/*.gif (make gifs).
- Library cards (tiers A/B/C) are parsed from docs/08-effects-library.md, so the page stays in sync
   with the doc. Previews use VICE captures where available and browser simulations otherwise.
The page is a single self-contained file apart from the GIFs (relative paths).
"""
import glob
import html
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(ROOT, "docs", "08-effects-library.md")
JS = os.path.join(ROOT, "tools", "effects_page.js")
OUT = os.path.join(ROOT, "docs", "effects.html")

# (example ID, name, description, code, GIF)
EXAMPLE_CAPTURES = [
    ("00", "Minimal executable",
     "BASIC upstart, machine takeover, frame sync by polling $d012, border colour cycle.", "`docs/examples/00_hello.asm`", "ex-hello.gif"),
    ("01", "Raster IRQ split",
     "Two chained raster interrupts split the screen into colour zones.", "`docs/examples/01_raster_irq.asm`", "ex-raster-irq.gif"),
    ("02", "Stable raster bars",
     "Full-height cycle-exact bars with the screen blanked (no badlines).", "`docs/examples/02_stable_raster_bars.asm`", "ex-stable-bars.gif"),
    ("03", "Smooth scroller",
     "The scroller technique on its own.", "`docs/examples/03_smooth_scroller.asm`", "ex-scroller.gif"),
    ("04", "Sprites on sine tables",
     "8 hardware sprites following sine tables generated at assemble time, X MSB handling.", "`docs/examples/04_sprites_sine.asm`", "ex-sprites-sine.gif"),
]

LIBRARY_CAPTURES = {"B30": "ex-heads.gif"}

TIERS = {
    "A": ("Tier A — one-prompt effects", "Data or colour-RAM change only; safe to do live on stage."),
    "B": ("Tier B — small routines", "New routine or jitter-tolerant raster IRQ; prepare beforehand."),
    "C": ("Tier C — cycle-exact / heavy", "Stable raster on every line, big tables; prepare off-stage, test on hardware."),
}


def md_inline(s):
    s = html.escape(s)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", s)
    return s


def link_sources(s):
    """cb:base:xyz -> link to codebase64."""
    return re.sub(r"cb:([a-z0-9_:\-]+)",
                  lambda m: f'<a href="https://codebase64.net/doku.php?id={m.group(1)}">{m.group(1)}</a>', s)


def parse_demo():
    rows = []
    seen = set()
    with open(DOC, encoding="utf-8") as doc:
        for line in doc:
            if not line.startswith("| [D"):
                continue
            m = re.fullmatch(r"\| \[(D\d{2,})\]\(effects\.html#\1\) \|(.+)\|\s*", line)
            if not m:
                raise ValueError(f"Invalid demo reference: {line.strip()}")
            fx_id = m.group(1)
            if fx_id in seen:
                raise ValueError(f"Duplicate demo reference: {fx_id}")
            name, desc, code, gif = (cell.strip() for cell in m.group(2).split("|"))
            gif = gif.strip("`")
            if not os.path.isfile(os.path.join(ROOT, "docs", "img", "effects", gif)):
                raise ValueError(f"{fx_id}: missing capture {gif} (run make gifs)")
            seen.add(fx_id)
            rows.append((fx_id, name, desc, f"`src/main.asm`: {code}", gif))
    if not rows:
        raise ValueError("No demo references found in the effects library")
    return rows


def parse_library():
    rows = []
    for line in open(DOC, encoding="utf-8"):
        m = re.match(r"\|\s*([ABC]\d+)\s*\|(.*)\|\s*$", line)
        if not m:
            continue
        cells = [c.strip() for c in m.group(2).split("|")]
        fx_id, tier = m.group(1), m.group(1)[0]
        if tier in "AB":   # Effect | What you see | How | CPU | Where/Source
            name, see, how, cpu, where = (cells + [""] * 5)[:5]
        else:              # Effect | What you see | Why it's hard | Source
            name, see, how, where = (cells + [""] * 4)[:4]
            cpu = "heavy"
        rows.append(dict(id=fx_id, tier=tier, name=name, see=see, how=how, cpu=cpu, where=where))
    return rows


def card_capture(fx_id, name, desc, where, gif, *, demo=False):
    anchor = fx_id if demo else f"example-{fx_id}"
    tag = "in the demo" if demo else "standalone example"
    card_class = "card done" if demo else "card"
    return f"""<article id="{anchor}" class="{card_class}" data-text="{html.escape(f'{fx_id} {name} {desc}'.lower())}">
  <div class="pic"><img src="img/effects/{gif}" alt="{html.escape(name)}" loading="lazy"></div>
  <h3><a class="id" href="#{anchor}">{fx_id}</a> {html.escape(name)} <span class="tag ok">{tag}</span></h3>
  <p>{md_inline(desc)}</p>
  <p class="meta">Code: {md_inline(where)} · capture: real VICE (PAL)</p>
</article>"""


def example_link(fx_id):
    files = glob.glob(os.path.join(ROOT, "docs", "examples", f"{fx_id[0]}{int(fx_id[1:]):02d}_*.asm"))
    if not files:
        return ""
    f = os.path.basename(files[0])
    return f' · example: <a href="examples/{f}"><code>{f}</code></a>'


def card_lib(r):
    capture = LIBRARY_CAPTURES.get(r["id"])
    if capture:
        preview = (f'<img src="img/effects/{capture}" alt="{html.escape(r["name"])}" loading="lazy">'
                   '<span class="sim">PAL VICE capture</span>')
    else:
        preview = f'<canvas data-fx="{r["id"]}"></canvas><span class="sim">simulation</span>'
    return f"""<article id="{r['id']}" class="card" data-tier="{r['tier']}" data-text="{html.escape((r['id'] + ' ' + r['name'] + ' ' + r['see']).lower())}">
  <div class="pic">{preview}</div>
  <h3><span class="id">{r['id']}</span> {md_inline(r['name'])}</h3>
  <p>{md_inline(r['see'])}</p>
  <details><summary>How</summary><p>{link_sources(md_inline(r['how']))}</p></details>
  <p class="meta">CPU: {md_inline(r['cpu'])} · {link_sources(md_inline(r['where']))}{example_link(r['id'])}</p>
</article>"""


def main():
    demo = parse_demo()
    lib = parse_library()
    parts = [f'<section id="done"><h2>In the demo ({len(demo)})</h2>'
             '<p class="lead">Use these reference IDs in prompts and issue reports. '
             'Captures show the real program running in PAL VICE.</p>'
             '<div class="grid">' + "\n".join(card_capture(*e, demo=True) for e in demo) + "</div></section>",
             f'<section id="examples"><h2>Standalone examples ({len(EXAMPLE_CAPTURES)})</h2>'
             '<div class="grid">' + "\n".join(card_capture(*e) for e in EXAMPLE_CAPTURES) + "</div></section>"]
    for t, (title, lead) in TIERS.items():
        cards = [card_lib(r) for r in lib if r["tier"] == t]
        parts.append(f'<section id="tier{t}" class="tier"><h2>{title} ({len(cards)})</h2><p class="lead">{lead} '
                     'Each preview is labelled as a PAL VICE capture or a browser simulation.</p>'
                     '<div class="grid">' + "\n".join(cards) + "</div></section>")
    page = TEMPLATE.replace("%BODY%", "\n".join(parts)).replace("%JS%", open(JS, encoding="utf-8").read()) \
        .replace("%COUNT%", str(len(demo) + len(EXAMPLE_CAPTURES) + len(lib)))
    open(OUT, "w", encoding="utf-8").write(page)
    print(f"{os.path.relpath(OUT, ROOT)}: {len(demo)} demo references + {len(EXAMPLE_CAPTURES)} examples + {len(lib)} library recipes")


TEMPLATE = """<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>opencode-c64 — demo effects</title>
<!-- generated by tools/effects_page.py from docs/08-effects-library.md - do not edit -->
<style>
:root{--bg:#2c3dec;--panel:#000;--fg:#7385ff;--hi:#fff;--ok:#56ac4d;--warn:#ffff46}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.45 ui-monospace,Menlo,Consolas,monospace}
header{background:#000;padding:20px 24px;border-bottom:8px solid #7385ff}
h1{margin:0;color:var(--hi);font-size:22px;letter-spacing:1px}
header p{margin:6px 0 0}
nav{position:sticky;top:0;z-index:2;background:#000c;padding:10px 24px;display:flex;gap:10px;flex-wrap:wrap;align-items:center}
nav a,nav button{color:var(--hi);background:#2c3dec;border:0;padding:4px 10px;font:inherit;cursor:pointer;text-decoration:none}
nav button.on{background:#7385ff;color:#000}
nav input{font:inherit;padding:4px 8px;background:#000;color:var(--hi);border:1px solid #7385ff;min-width:220px}
main{padding:0 24px 40px}
h2{color:var(--hi);margin:28px 0 4px}
.lead{margin:0 0 14px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:14px}
.card{background:var(--panel);padding:12px;border:2px solid #000;display:flex;flex-direction:column;scroll-margin-top:70px}
.card.done{border-color:var(--ok)}
.pic{position:relative;background:#000;display:flex;align-items:center;justify-content:center;min-height:120px;margin-bottom:8px}
.pic img,.pic canvas{width:100%;image-rendering:pixelated;display:block}
.pic canvas{aspect-ratio:16/10}
.sim{position:absolute;right:4px;bottom:4px;background:#000a;color:var(--warn);font-size:10px;padding:1px 4px}
h3{margin:0 0 4px;color:var(--hi);font-size:15px}
.id{color:var(--warn)}
.tag{font-size:10px;padding:1px 5px;vertical-align:middle}
.tag.ok{background:var(--ok);color:#000}
p{margin:0 0 6px}
.meta{margin-top:auto;font-size:12px;opacity:.85}
code{color:#7ef3d6}
a{color:#b7ff86}
details summary{cursor:pointer;color:var(--hi)}
.hidden{display:none}
footer{padding:16px 24px;background:#000;font-size:12px}
</style></head>
<body>
<header>
  <h1>**** OPENCODE C64 — DEMO EFFECTS ****</h1>
  <p>%COUNT% demo references, examples, and recipes for Codeurs en Seine 2026.
  Green cards show what runs in the demo today.</p>
</header>
<nav>
  <a href="#done">In the demo</a><a href="#examples">Examples</a><a href="#tierA">Tier A</a><a href="#tierB">Tier B</a><a href="#tierC">Tier C</a>
  <input id="q" placeholder="search (D01, plasma, sprite...)">
</nav>
<main>
%BODY%
</main>
<footer>Sources: Codebase64 wiki (CC BY-NC-SA 4.0), C= Hacking "Demo corner", CSDb.
Regenerate: <code>make gifs</code> (captures) then <code>make effects-page</code>.</footer>
<script>
document.getElementById("q").addEventListener("input", e => {
  const q = e.target.value.toLowerCase().trim();
  document.querySelectorAll(".card[data-text]").forEach(c => c.classList.toggle("hidden", q && !c.dataset.text.includes(q)));
});
</script>
<script>
%JS%
</script>
</body></html>
"""

if __name__ == "__main__":
    main()
