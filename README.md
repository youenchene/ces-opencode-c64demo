# opencode-c64

A small demoscene-style Commodore 64 intro that presents [opencode](https://opencode.ai) at
[Codeurs en Seine 2026](https://www.codeursenseine.com/2026) (Rouen, Kindarena, 19 November 2026),
written in 6502 assembly and runnable on a real (PAL) C64.

- Codeurs en Seine logo with a shine sweep, Rouen skyline (cathedral, Saint-Ouen, Flaubert bridge)
  over a shimmering Seine
- Stable raster "copper" bars in the top border
- 1x1 smooth scroller
- Optional SID music

```sh
brew install acme vice
make run          # build + launch in VICE
make d64          # disk image for real hardware
```

Agents (and humans): start with [AGENTS.md](AGENTS.md) and [docs/](docs/README.md).
