# Build provenance

- Target: Leaf MLP1, AArch64 Linux, GLES, glibc supplied by the Leaf SDK.
- SDK: ghcr.io/utility-muffin-research-kitchen/mlp1-toolchain@sha256:3fa668ce6d399f57f1d391e8a8253f5017ab6d52e71b97ce5b1e955868124014
- mkxp-z: https://github.com/mkxp-z/mkxp-z at f02d586624dc53de373889cc16d9b1516da0a3a5 (2.4.2).
- Build changes: patches/mlp1-gles.patch checks GLES instead of unused desktop GL and corrects SDL image/TTF pkg-config names for the SDK; patches/mlp1-ttf.patch includes the SDK font declaration instead of declaring an incompatible struct.
- patches/mlp1-game-config.patch loads the game's JSON5 configuration before Leaf's generated configuration when MKXPZ_LEAF_GAME_CONFIG is set by the wrapper. This preserves game preload scripts and other compatibility settings.
- patches/mlp1-legacy-input.patch exposes the existing Input mouse and raw keyboard functions on System for games using the older mkxp interface.
- patches/mlp1-fullscreen.patch keeps the physical SDL window fullscreen when MKXPZ_LEAF_FULLSCREEN is set by Leaf, while allowing games to resize their logical rendering canvas and refreshing the display scaling.
- patches/mlp1-controller.patch optionally translates SDL controller buttons and axes into keyboard states using a per-game controller.keys file. Keyboard input remains available, and direct RGSS controller bindings are suppressed for that profile to prevent duplicate actions. tests/test_controller.cpp was cross-compiled and passed on the target device.
- The launcher now prefers controller.keys beside the game, falling back to the legacy userdata profile; it resolves the path on every launch. The SA preset maps A to X and B to Z.
- patches/mlp1-frame-trace.patch adds optional, buffered native frame timing, bounded to four minutes and disabled by default. No Graphics.update Ruby alias changes are involved.
- The optional SA performance profile reduces map-loop allocations, preserves successful native hash membership lookups, and avoids intermediate map-renderer work during the recognized Better Speed Up plugin's acceleration. Shadows can be disabled separately. These are experimental optimizations; device feedback indicates only limited improvement, and no fixed FPS gain is promised.
- Host Meson: 1.10.2; target compiler: GCC 12.3.0 (Leaf Buildroot toolchain).
- Dependency source revisions and hashes: upstream subprojects/*.wrap. Meson verifies downloaded archives before use. Needed dependencies absent from the SDK are built from those sources.
- mkxp-z license: GPL-2.0-or-later; the OpenSSL-enabled combined executable uses upstream LICENSE.mkxp-z-with-https.txt (GPL-3.0). See the installed LICENSE.txt and the corresponding-source archive for dependency license texts.
- Artwork: scripts/gen_icon.py generates the abstract icon; original artwork dedicated to the public domain (CC0-1.0).
- Content contract: leaf-contracts a641d6d6977e0bd76dde63d55045783c0724bce9.
- Local build image: mkxp-z-mlp1-build:local, sha256:2b1b161ba192a051608ed9cbe5d04071ff39f765fab4aa389a8aa6cd3bebb92e. Host dependencies were installed inside a container created from the pinned SDK, then saved for reuse.

The binary uses SDK-provided shared libraries listed in build/binary-report.json. The pak includes SDK libfmt.so.10 in a private lib directory because the tested device firmware supplies only fmt 9. Other shared libraries come from the firmware. ADB verification on the target device resolved the complete dependency closure; game execution still requires testing.

Publish mkxp-z-corresponding-source.tar.gz next to the binary ZIP. It contains the exact modified source tree, fetched dependency sources, wrapper and build instructions. No RPG Maker RTP, games, soundfonts or proprietary runtime DLLs are distributed.
