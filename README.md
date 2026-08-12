# Deep Contract / 海渊契约

A pixel-art escape simulation set on a deep-sea drilling platform, built with Godot 4.7.1 and
targeting the iOS App Store.

You are a technician bound to Rig Abyss-9 by a contract that keeps renewing itself. The rig sits
1,800 metres below the surface, so there is no fence to climb and no gate to walk through — the
only way out is to build something that floats.

The game borrows its viewpoint and loop from The Escapists 1/2: a top-down 3/4 pixel view, a
rigid daily schedule with roll calls, guard patrols with vision cones, contraband and shakedowns,
crafting, stat training, and several independent escape routes. What it adds on top is the deep
sea itself — oxygen bottles, pressurised compartments, and scheduled blackouts that briefly blind
the rig's cameras.

## Requirements

- [Godot 4.7.1-stable](https://godotengine.org/download) (no C#/Mono variant needed)
- Python 3.10+ with [Pillow](https://pypi.org/project/Pillow/) — only to regenerate art and audio
- Bash, curl, unzip

`tools/get_godot.sh` downloads the pinned engine build into `.tools/` so local runs and CI use the
exact same version. `.tools/` is gitignored.

## Getting started

```bash
tools/get_godot.sh          # fetch the pinned Godot build into .tools/
tools/check_import.sh       # headless reimport, fails on any Godot error
tools/run_tests.sh          # run the GUT suite headlessly
.tools/godot --path .       # play the game
```

To use an engine binary you already have, set `GODOT_BIN`:

```bash
GODOT_BIN=/path/to/godot tools/run_tests.sh
```

## Layout

| Path | Contents |
| --- | --- |
| `scenes/` | Scene files, split into `world`, `ui`, `actors`, `systems` |
| `scripts/` | GDScript, mirroring the scene split plus `core` for autoloads |
| `data/` | Data-driven definitions: items, recipes, schedule, NPCs, jobs, escape routes |
| `assets/generated/` | Art and audio produced by `tools/gen_art.py` and `tools/gen_audio.py` |
| `tests/unit/` | GUT tests |
| `tools/` | Toolchain and asset-generation scripts |
| `fastlane/` | iOS signing and TestFlight delivery |
| `docs/` | Design notes and the App Store submission checklist |

## Art pipeline

Every sprite is generated procedurally by `tools/gen_art.py` from a fixed 16-colour palette, then
committed to the repository. Nothing is sourced from third-party asset packs, so the project
carries no attribution or licensing obligations. Regenerate with:

```bash
python3 tools/gen_art.py
```

## Shipping to iOS

Apple's toolchain only runs on macOS, so a Linux or Windows machine cannot produce an `.ipa`
directly. This repository works around that by letting Godot export an Xcode project and having a
GitHub Actions macOS runner do the signing and upload via fastlane:

```
Godot (any OS) --> Xcode project --> macOS runner --> fastlane match/gym/pilot --> TestFlight
```

See [docs/APPSTORE.md](docs/APPSTORE.md) for the required secrets and the one-time setup.

## Licence

Code and generated assets in this repository are original work. See `docs/APPSTORE.md` for
third-party components bundled at build time (Godot engine, GUT).
