# opencode-c64 build
# Requires: acme (brew install acme), VICE (brew install vice) for x64sc + c1541
# Optional: exomizer (packing), see docs/01-toolchain.md

ACME      ?= acme
X64       ?= x64sc
C1541     ?= c1541
EXOMIZER  ?= exomizer
# Music is on when src/music/music.sid exists (make MUSIC=0 to turn it off).
MUSIC     ?= $(if $(wildcard src/music/music.sid),1,0)
TIMING    ?= 0
# SID chip VICE emulates: 1 = 8580 (Teh Disco is written for it), 0 = 6581
SIDMODEL  ?= 1

BUILD     := build
ACMEFLAGS := -I include -f cbm --cpu 6502

DEMO      := $(BUILD)/opencode.prg
D64       := $(BUILD)/opencode.d64
EXAMPLES  := $(patsubst docs/examples/%.asm,$(BUILD)/examples/%.prg,$(wildcard docs/examples/*.asm))

.PHONY: all demo examples gfx gifs effects-page d64 run run-example packed shots clean

all: demo examples

demo: $(DEMO)

$(DEMO): src/main.asm include/c64.asm $(wildcard src/gfx/*.asm) $(wildcard src/music/*.sid) | $(BUILD)
	$(ACME) $(ACMEFLAGS) -DMUSIC=$(MUSIC) -DTIMING=$(TIMING) -l $(BUILD)/opencode.sym -r $(BUILD)/opencode.lst -o $@ $<

examples: $(EXAMPLES)

$(BUILD)/examples/%.prg: docs/examples/%.asm include/c64.asm | $(BUILD)
	@mkdir -p $(BUILD)/examples
	$(ACME) $(ACMEFLAGS) -l $(@:.prg=.sym) -o $@ $<

# Regenerate charset graphics from assets/ (needs rsvg-convert for SVG: brew install librsvg).
# The generated src/gfx/*.asm are committed, so a normal build doesn't need this.
gfx:
	python3 tools/img2chars.py ces_logo assets/codeurs-en-seine-logo.svg --svg-width 210 --crop --optimize
	python3 tools/img2chars.py rouen assets/rouen.txt

# Disk image for SD2IEC / Kung Fu Flash / 1541 Ultimate / real 1541
d64: $(DEMO)
	$(C1541) -format "opencode,oc" d64 $(D64) -write $(DEMO) opencode

# Crunched single-file executable (faster loading on a stock 1541)
packed: $(DEMO)
	$(EXOMIZER) sfx basic -o $(BUILD)/opencode-packed.prg $(DEMO)

run: $(DEMO)
	$(X64) -pal -sidmodel $(SIDMODEL) -autostart $(DEMO)

# make run-example EX=02_stable_raster_bars
run-example: examples
	$(X64) -pal -autostart $(BUILD)/examples/$(EX).prg

# Headless check: run every PRG ~9M cycles in warp, save screenshot, print summary.
# Exit code 1 from x64sc is expected (-limitcycles).
shots: all
	@mkdir -p $(BUILD)/shots
	@for p in $(DEMO) $(EXAMPLES); do n=$$(basename $$p .prg); \
	  $(X64) -pal -default -warp -autostartprgmode 1 -limitcycles 9000000 \
	    -exitscreenshot $(BUILD)/shots/$$n.png -autostart $$p >/dev/null 2>&1; \
	  echo "shot: $(BUILD)/shots/$$n.png"; done
	python3 tools/pngsum.py $(BUILD)/shots/*.png

# Animated GIFs of the implemented effects for docs/effects.html (takes a few minutes).
# Crops use screenshot pixels: text row r starts at y = 35 + r*8, column c at x = 32 + c*8.
CAP  := python3 tools/capture_gif.py
GIFS := docs/img/effects
gifs: all
	@mkdir -p $(GIFS)
	$(CAP) $(DEMO) $(GIFS)/demo-ces.gif        --start 6000000  --frames 24 --step 2 --scale 2
	$(CAP) $(DEMO) $(GIFS)/demo-opencode.gif   --start 30000000 --frames 24 --step 4 --scale 2
	$(CAP) $(DEMO) $(GIFS)/copper-bars.gif     --start 6000000  --frames 32 --step 1 --crop 0,0,384,40
	$(CAP) $(DEMO) $(GIFS)/scroller.gif        --start 6000000  --frames 32 --step 1 --crop 0,220,384,22
	$(CAP) $(DEMO) $(GIFS)/ces-shine.gif       --start 6000000  --frames 32 --step 2 --crop 32,40,320,100
	$(CAP) $(DEMO) $(GIFS)/rouen-seine.gif     --start 6000000  --frames 16 --step 2 --crop 32,145,320,84
	$(CAP) $(DEMO) $(GIFS)/logo-rainbow.gif    --start 30000000 --frames 32 --step 1 --crop 32,40,320,46
	$(CAP) $(DEMO) $(GIFS)/typer.gif           --start 12500000 --frames 48 --step 8 --crop 32,85,320,130
	$(CAP) $(BUILD)/examples/00_hello.prg $(GIFS)/ex-hello.gif --start 6000000 --frames 16 --step 4 --scale 2
	$(CAP) $(BUILD)/examples/01_raster_irq.prg $(GIFS)/ex-raster-irq.gif --start 6000000 --frames 1 --scale 2
	$(CAP) $(BUILD)/examples/02_stable_raster_bars.prg $(GIFS)/ex-stable-bars.gif --start 6000000 --frames 32 --step 2 --scale 2
	$(CAP) $(BUILD)/examples/03_smooth_scroller.prg $(GIFS)/ex-scroller.gif --start 6000000 --frames 32 --step 1 --crop 0,220,384,22
	$(CAP) $(BUILD)/examples/04_sprites_sine.prg $(GIFS)/ex-sprites-sine.gif --start 6000000 --frames 32 --step 1 --scale 2

# docs/effects.html: visual catalogue (implemented effects = GIFs above, library = docs/08)
effects-page:
	python3 tools/effects_page.py

$(BUILD):
	@mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
