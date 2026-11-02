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

Put an optional `controller.keys` in the game directory, beside `Game.ini` and
`mkxp.json`. The launcher selects it anew on every game launch; edit the file
and restart the game to apply changes. If it is absent, the launcher falls back
to the old `USERDATA_PATH/mkxp-z/<game-key>/controller.keys` location. If neither
exists, mkxp-z uses its normal controller bindings.
Each line maps an SDL controller button/axis
to a keyboard key, for example `a=X`, `b=Z`, `lefttrigger=Q`, or `leftx-=Left`.
Use UTF-8 without a BOM. Lines starting with `#` are comments.
When enabled, the profile replaces direct RGSS controller bindings and also
feeds the raw keyboard API used by games with custom controls. The physical
keyboard remains active. The stick dead zone is 16000 of 32767.
`emulators/mkxp-z/profiles/pokemon-sa.keys` supplies the SA preset:

| Handheld | Keyboard | SA action |
| --- | --- | --- |
| D-pad / left stick | Arrows | Move |
| A / B | X / Z | Cancel or run / confirm |
| X / Y | C / W | Menu / Pokedex |
| L / R | A / S | Previous / next page |
| L2 / R2 | Q / D | Speed / registered action |
| Start / Select | C / Enter | Menu / confirm |

Leaf's Menu return-to-launcher behavior is used; Leaf save states and Game
Switcher are not supported. Save in the game's own menu before exiting.
The binary and package are checked on the build host; display, audio, controls
and game execution still require testing on a physical MLP1.

## Pokemon SA timing compatibility (v1.0.4)

The optional `emulators/mkxp-z/profiles/pokemon-sa-timing.rb` preload fixes
SA's conversion of `Graphics.delta` from seconds as though it were microseconds.
The incorrect conversion can stall the battle-entry flash while music keeps
playing. The corrected profile was tested on an MLP1 and battle scenes work.
It overrides only `Graphics.delta_s`, preserving the game's speed-plugin
`Graphics.update` alias chain. This is a game-specific profile, not a global fix.

Copy this profile to a persistent location on the card and append its absolute
path to the game's existing `preloadScript` array in `mkxp.json`. Keep all
existing preload entries. Set `fixedFramerate` to `0` so the game controls its
frame rate. Restart the game after changing the configuration. To disable the
profile, remove only its entry from `preloadScript` and restart.

Keep `"patches": ["patch"]` if using JoiPlay's existing map optimization files;
those Data and Graphics files must stay together. The experimental static
battler overlay was rolled back after device testing and is not included in
this release. No game assets or saves are distributed.

For troubleshooting, the timing preload records frame-rate, Ruby GC and
main-thread stack samples every five seconds for the first three minutes to
`leaf-performance.log` in the game's mkxp-z data directory. The profile does
not force garbage collection or write logs on each frame.

### Optional SA performance profile (device validation in progress)

`emulators/mkxp-z/profiles/pokemon-sa-performance.rb` is a separate opt-in
profile. Copy it and the adjacent `pokemon-sa-performance.conf` to a persistent
directory on the card, then append the Ruby file's absolute path to the game's
existing `preloadScript` array. Keep the timing profile and original map patches.
Restart the game to apply changes.

The default settings hide character foot shadows and dynamic character
projections. They also fuse the Essentials and MakerStudio tile-coordinate
methods, preserving scroll offsets and rotated/flipped tile alignment. The
`batched_tiles` setting replaces the core tile traversal with a loop that reuses
its visited-cell buffer and reads map data once per map. MakerStudio's outer
lighting, extended-layer, fog and map-shadow updates still run normally. Local
comparison against the existing engine method covered 48 scene transitions;
host timing of the isolated loop is not a handheld FPS benchmark. The
`hash_lookup` setting works around Luka's Scripting Utilities rebuilding and
scanning the complete hash key array on every membership query. Successful
plain Symbol/Integer lookups use native `key?`; other keys and all misses retain
the original plugin's semantics, including multiple query arguments. This only
installs when that plugin's override and the native `key?` are detected. The
profile installs after `PluginManager.runPlugins` returns, so plugin aliases
are already in place. It does not hook `Graphics.update`, change frame rate,
skip event updates or replace game assets. MakerStudio's map shadow layers,
reflections and fog remain controlled by the game.

Set `shadows=on` to restore character shadows, `tile_coordinates=off` to disable
only the coordinate optimization, `batched_tiles=off` to restore the original
tile traversal, or `enabled=off` to restore all original
behaviours on the next launch. Removing this profile from `preloadScript` also
disables it. Unknown settings cause the profile to log an error and skip setup.
Performance gains still require a comparison on the same map and route.
Use `hash_lookup=off` to disable only the hash membership workaround.

`speedup_render=on` targets the game's Better Speed Up plugin: during Q
acceleration, prepare the map renderer once immediately before each displayed
frame instead of on every intermediate logical tick. Player, event, interpreter
and character updates retain their original cadence. Normal speed, menus,
battles, explicit map refreshes and transfers retain renderer updates. This
requires the recognized 1x/2x/3x plugin and MakerStudio renderer. Map visual
animation can differ during acceleration; device validation is still required.
Use `speedup_render=off` and restart to disable it.
