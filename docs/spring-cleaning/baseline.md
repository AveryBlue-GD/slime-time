# Spring cleaning baseline (tag `spring-cleaning-baseline`, commit dfbfccb, branch v2)

Measured 2026-10-15 on the dev Mac (Apple M3).

| Measure | Baseline |
|---|---|
| Test suites | 70, all passing |
| Full `./tools/test_all.sh` wall time | 5 min 58 s |
| GDScript lines (scripts + tests + tools) | 42,859 |
| Scripts (`scripts/**/*.gd`) | 64 |
| Test files (`tests/**/*.gd`) | 116 |
| `assets/` on disk | 20 MB |
| `docs/` on disk | 58 MB |
| Git pack size | 25.2 MiB |
| Web export `index.pck` | 5,293,612 bytes |
| Web export `index.wasm` (engine) | 39,514,754 bytes |

Targets (owner): stable 60 fps on low-end PCs and low-to-mid mobile; scale smoothly to high refresh rates (120/144/240 Hz) on better rigs. English only.
