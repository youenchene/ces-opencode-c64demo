#!/usr/bin/env python3
"""Build docs/effects.html: a visual catalogue of every demo effect.

Usage: python3 tools/effects_page.py        (or: make effects-page)

- "In the demo" cards use real VICE captures from docs/img/effects/*.gif (make gifs).
- Library cards (tiers A/B/C) are parsed from docs/08-effects-library.md, so the page stays in sync
  with the doc. Their previews are browser simulations (tools/effects_page.js), marked as such.
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

# (gif, name, description, where in the code)
IMPLEMENTED = [
    ("demo-ces.gif", "Part \"ces\" (full screen)",
     "Codeurs en Seine logo, date line, Rouen skyline over the Seine, copper bars and scroller.", "src/main.asm part_ces"),
    ("demo-opencode.gif", "Part \"opencode\" (full screen)",
     "Block logo with rainbow, subtitle and the simulated terminal session.", "src/main.asm part_opencode"),
    ("copper-bars.gif", "Stable raster copper bars",
     "Double-IRQ stable raster, one colour per raster line in the top border, rotated every frame.", "irq_bars1/2, rotate_bars"),
    ("scroller.gif", "1x1 smooth scroller",
     "$d016 fine scroll + char shift, raster split so only row 24 moves, 38-column mode hides the edges.", "irq_split, scroller_update"),
    ("ces-shine.gif", "Charset logo + shine sweep",
     "Official logo converted to 106 custom chars; a white glint crosses it through colour RAM only.", "ces_shine, tools/img2chars.py"),
    ("rouen-seine.gif", "Charset split + water shimmer",
     "Second charset below row 13 (raster IRQ on $d018) for the skyline; the Seine cycles blue tones.", "irq_mid, water_colors"),
    ("logo-rainbow.gif", "Colour-cycled block logo",
     "Logo built from reverse spaces; a diagonal rainbow runs through colour RAM.", "draw_logo, logo_colors"),
    ("typer.gif", "Terminal typer",
     "Byte stream with colour/pause/newline codes, printed char by char with a blinking cursor.", "typer_update"),
    ("ex-hello.gif", "Example 00: minimal executable",
     "BASIC upstart, machine takeover, frame sync by polling $d012, border colour cycle.", "docs/examples/00_hello.asm"),
    ("ex-raster-irq.gif", "Example 01: raster IRQ split",
     "Two chained raster interrupts split the screen into colour zones.", "docs/examples/01_raster_irq.asm"),
    ("ex-stable-bars.gif", "Example 02: stable raster bars",
     "Full-height cycle-exact bars with the screen blanked (no badlines).", "docs/examples/02_stable_raster_bars.asm"),
    ("ex-scroller.gif", "Example 03: smooth scroller",
     "The scroller technique on its own.", "docs/examples/03_smooth_scroller.asm"),
    ("ex-sprites-sine.gif", "Example 04: sprites on sine tables",
     "8 hardware sprites following sine tables generated at assemble time, X MSB handling.", "docs/examples/04_sprites_sine.asm"),
    ("ex-heads.gif", "Example B30: bouncing portrait sprites",
     "Two portrait cutouts spin like wheels and bounce off the screen edges. Standalone example.", "docs/examples/B30_rotating_heads.asm"),
]

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


def card_impl(gif, name, desc, where):
    tag = "standalone example" if gif == "ex-heads.gif" else "in the demo"
    return f"""<article class="card done">
  <div class="pic"><img src="img/effects/{gif}" alt="{html.escape(name)}" loading="lazy"></div>
  <h3>{html.escape(name)} <span class="tag ok">{tag}</span></h3>
  <p>{md_inline(desc)}</p>
  <p class="meta">Code: {md_inline('`' + where + '`')} · capture: real VICE (PAL)</p>
</article>"""


def example_link(fx_id):
    files = glob.glob(os.path.join(ROOT, "docs", "examples", f"{fx_id[0]}{int(fx_id[1:]):02d}_*.asm"))
    if not files:
        return ""
    f = os.path.basename(files[0])
    return f' · example: <a href="examples/{f}"><code>{f}</code></a>'


def card_lib(r):
    return f"""<article class="card" data-tier="{r['tier']}" data-text="{html.escape((r['name'] + ' ' + r['see']).lower())}">
  <div class="pic"><canvas data-fx="{r['id']}"></canvas><span class="sim">simulation</span></div>
  <h3><span class="id">{r['id']}</span> {md_inline(r['name'])}</h3>
  <p>{md_inline(r['see'])}</p>
  <details><summary>How</summary><p>{link_sources(md_inline(r['how']))}</p></details>
  <p class="meta">CPU: {md_inline(r['cpu'])} · {link_sources(md_inline(r['where']))}{example_link(r['id'])}</p>
</article>"""


def main():
    lib = parse_library()
    parts = [f'<section id="done"><h2>In the demo now ({len(IMPLEMENTED)})</h2>'
             '<p class="lead">Animated captures of the real program running in VICE (<code>make gifs</code>).</p>'
             '<div class="grid">' + "\n".join(card_impl(*e) for e in IMPLEMENTED) + "</div></section>"]
    for t, (title, lead) in TIERS.items():
        cards = [card_lib(r) for r in lib if r["tier"] == t]
        parts.append(f'<section id="tier{t}" class="tier"><h2>{title} ({len(cards)})</h2><p class="lead">{lead} '
                     'Previews are browser simulations in the C64 palette, not C64 code.</p>'
                     '<div class="grid">' + "\n".join(cards) + "</div></section>")
    page = TEMPLATE.replace("%BODY%", "\n".join(parts)).replace("%JS%", open(JS, encoding="utf-8").read()) \
        .replace("%COUNT%", str(len(IMPLEMENTED) + len(lib)))
    open(OUT, "w", encoding="utf-8").write(page)
    print(f"{os.path.relpath(OUT, ROOT)}: {len(IMPLEMENTED)} implemented + {len(lib)} library effects")


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
.card{background:var(--panel);padding:12px;border:2px solid #000;display:flex;flex-direction:column}
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
  <p>%COUNT% effects for the Codeurs en Seine 2026 demo. Green cards run in the demo today (real captures);
  the rest is the library from <code>docs/08-effects-library.md</code>, previewed as browser simulations.</p>
</header>
<nav>
  <a href="#done">In the demo</a><a href="#tierA">Tier A</a><a href="#tierB">Tier B</a><a href="#tierC">Tier C</a>
  <input id="q" placeholder="search (plasma, sprite, border...)">
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
