# mkxp-z for Leaf MLP1

Standalone mkxp-z 2.4.2 content pak for RPG Maker XP, VX and VX Ace (RGSS 1/2/3).
RPG Maker 2000/2003, MV and MZ are not supported by mkxp-z.

## Build with local Docker

The base image is the official toolchain from
https://leaf.game/develop/building/ . Its SHA256 is pinned in docker/Dockerfile.
The derived image adds host build tools and Meson 1.10.2; compilation still
uses the SDK's AArch64 GCC 12.3.0 and sysroot, not the host compiler.

From this checkout, in PowerShell:

```powershell
docker build -f docker/Dockerfile -t mkxp-z-mlp1-build .
docker run --rm -v "${PWD}:/work" -w /work mkxp-z-mlp1-build sh -c 'export PATH=/usr/local/bin:$PATH; make package check source'
```

Outputs:

- `build/package/mkxp-z.pak/`: installable directory.
- `build/dist/mkxp-z.mlp1.pak.zip`: ZIP preserving executable permissions.
- `build/dist/mkxp-z-corresponding-source.tar.gz`: exact source and build scripts.
- `build/compile.log`: build log from the initial local Docker run.

Dependencies are cached under `build/`. The native host compiler only builds
build-time tools; the runtime is AArch64. See docs/PROVENANCE.md for source,
SDK, patch and license details. Publish the corresponding-source archive next
to the binary ZIP. No proprietary RTP, games or fonts are included.

## Install and select a game

Extract `mkxp-z.pak` into `Apps/mlp1/` on the primary card. Example game layout:

```
Roms/MKXPZ/Example/
  Example.mkxp       # empty marker file, gives Leaf the desired game title
  Game.ini
  Data/
  Graphics/
  Audio/
```

Use an empty `.mkxp` marker inside each uncompressed game directory. The game
must contain its original Game.ini and resources. RGSS encrypted archives are
also accepted as launch entries, but external assets are still required and
ZIP/7z archives are not extracted by this pak. Rescan Leaf's library.

The launcher creates current-mount configuration on every invocation, uses
`SAVES_PATH` for mkxp-z's data directory and `USERDATA_PATH` for generated
launch configuration, and writes logs under `LOGS_PATH/mkxp-z.log`. Save keys
are derived from the ROM-relative directory, so card mount changes preserve
mkxp-z settings. Games that write saves directly beside Game.ini retain that
upstream behavior; this package does not rewrite game scripts or migrate saves.
The game's mkxp.json (JSON5) supplies preload scripts, fonts, RTP and other
game settings. Leaf overrides the game directory, data directory, Ruby library
paths, fullscreen and vsync. Compatibility with Windows-only DLLs and custom RGSS scripts
is not guaranteed by mkxp-z.
Leaf keeps the display fullscreen even if a game's saved settings request a
small desktop window; game rendering resolutions still scale to the display.

Optional controller profiles live in `USERDATA_PATH/mkxp-z/<game-key>/controller.keys`
beside the generated mkxp.json. Each line maps an SDL controller button/axis
to a keyboard key, for example `a=Z`, `lefttrigger=Q`, or `leftx-=Left`.
When enabled, the profile replaces direct RGSS controller bindings and also
feeds the raw keyboard API used by games with custom controls. The physical
keyboard remains active. The stick dead zone is 16000 of 32767.
`emulators/mkxp-z/profiles/pokemon-sa.keys` supplies the SA preset:

| Handheld | Keyboard | SA action |
| --- | --- | --- |
| D-pad / left stick | Arrows | Move |
| A / B | Z / X | Confirm / cancel or run |
| X / Y | C / W | Menu / Pokedex |
| L / R | A / S | Previous / next page |
| L2 / R2 | Q / D | Speed / registered action |
| Start / Select | C / Enter | Menu / confirm |

Leaf's Menu return-to-launcher behavior is used; Leaf save states and Game
Switcher are not supported. Save in the game's own menu before exiting.
The binary and package are checked on the build host; display, audio, controls
and game execution still require testing on a physical MLP1.
