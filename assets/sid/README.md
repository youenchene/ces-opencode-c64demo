# SID tunes (candidates for the demo)

Downloaded unchanged from HVSC (`https://hvsc.c64.org/download/C64Music/MUSICIANS/<path>`).
These are copyrighted works by their composers/publishers. They are kept here only to try them out in the
demo. **Ask the composer before playing one in public** (see `docs/05-music.md#sources-and-licensing`).

Listen: `vsid -sidmodel 1 assets/sid/Teh_Disco.sid` (`-sidmodel 0` for tunes marked 6581).
Use in the demo: copy to `src/music/music.sid` and `make MUSIC=1` (only for tunes that load at `$1000`
with init/play `$1000/$1003`, fit in 4 KB, and don't clash with our zero page `$f0-$fd`; see 05-music).

"ZP clash" = `(zp),y` pointers the player uses in `$f0-$fd` (rough scan, a hint only).

## Electro / demoscene shortlist

| File | Tune / composer / year | HVSC path | Load | Init / play | Model | ZP clash | Fits now? |
|---|---|---|---|---|---|---|---|
| `Teh_Disco.sid` | Teh Disco / Jammer / 2006 | `J/Jammer/Teh_Disco.sid` | `$1000-$1ea8` | `$1000/$1003` | 8580 | `$fb $fd` | after the ZP move |
| `Elektro_Klacz.sid` | Elektro Klacz / Jammer / 2018 | `J/Jammer/Elektro_Klacz.sid` | `$1000-$202b` | `$1000/$1003` | 8580 | `$fb` | no: 44 B over the slot |
| `Club_Style.sid` | Club Style / Jammer / 2004 | `J/Jammer/Club_Style.sid` | `$1000-$261e` | `$1000/$1003` | 8580 | `$fc` | no: needs 8 KB slot |
| `Disco_Proxima.sid` | Disco Proxima / Mibri / 2019 | `M/Mibri/Disco_Proxima.sid` | `$e000-$ed52` | `$e000/$e003` | 8580 | `$fc` | no: copy to `$e000` at start |
| `Galax_it_y.sid` | Galax(it)y / Laxity / 1988 | `L/Laxity/Galax_it_y.sid` | `$1000-$17bf` | `$1000/$1006` | 6581 | `$fc` | after ZP move + `MUSIC_PLAY=$1006` |
| `Rasters.sid` | Rasters / Jammer / 2019 | `J/Jammer/Rasters.sid` | `$3200-$34b4` | `$3200/$3203` | both | - | no: overlaps data |
| `Synthony.sid` | Synthony / Laxity / 1989-90 | `L/Laxity/Synthony.sid` | `$0f00-$22ff` | `$1000/$1006` | 6581 | `$fc` | no: overlaps code |

## Classic game tunes

| File | Tune / composer / year | HVSC path | Load | Init / play | Model | ZP clash | Song |
|---|---|---|---|---|---|---|---|
| `Commando.sid` | Commando / Rob Hubbard / 1985 | `H/Hubbard_Rob/Commando.sid` | `$5000-$5fc6` | `$5fb2/$5012` | 6581 | - | 1 of 19 |
| `Monty_on_the_Run.sid` | Monty on the Run / Rob Hubbard / 1985 | `H/Hubbard_Rob/Monty_on_the_Run.sid` | `$8000-$95bf` | `$8000/$8012` | 6581 | - | 1 of 19 |
| `Cybernoid_II.sid` | Cybernoid II / Jeroen Tel / 1988 | `T/Tel_Jeroen/Cybernoid_II.sid` | `$a600-$b717` | `$a600/$a603` | 6581 | - | 1 of 2 |
| `Wizball.sid` | Wizball / Martin Galway / 1987 | `G/Galway_Martin/Wizball.sid` | `$4600-$63da` | `$63ac/$6391` | 6581 | - | 4 of 9 |
| `Delta.sid` | Delta / Rob Hubbard / 1987 | `H/Hubbard_Rob/Delta.sid` | `$bc00-$cfff` | `$c357/$bde4` | 6581 | - | 12 of 13 |
| `Supremacy.sid` | Supremacy / Jeroen Tel / 1991 | `T/Tel_Jeroen/Supremacy.sid` | `$1000-$209f` | `$1000/$1003` | 6581 | - | 1 of 3 |

All are PSID, called once per frame (VBI), PAL.
