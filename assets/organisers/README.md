# Organiser photos (Codeurs en Seine)

Headshots of two Codeurs en Seine organisers, used in the standalone B30 rotating
heads example.

| File | Person | Source | Size |
|---|---|---|---|
| `etienne-reith.jpeg` | Etienne Reith (@EtienneReith) | https://www.codeursenseine.com/2026/organisateurs → `/images/organisers/etienne.jpeg` | 500x500 |
| `yann-petit.jpeg` | Yann Petit (@finalspy) | https://www.codeursenseine.com/2026/organisateurs → `/images/organisers/yann.jpeg` | 100x100 |

Both originals are published on the organisers page. Reuse rights for these
specific portraits were not verified; confirm before public presentation or redistribution.

Prepared cutouts (source art for `make gfx`):

| File | Made from | Size |
|---|---|---|
| `etienne-reith-face.png` | `etienne-reith.jpeg`, head masked and centered | 100x100 8-bit grey PNG |
| `yann-petit-face.png` | `yann-petit.jpeg`, head masked and centered | 100x100 8-bit grey PNG |

`tools/faces2sprites.py` converts each cutout into 16 in-plane rotation poses
made from four hires sprites each.
