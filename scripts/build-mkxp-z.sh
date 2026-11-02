#!/bin/sh
# Build the exact mkxp-z revision used by the pak. The Leaf MLP1 SDK supplies
# the compiler and SDL/OpenGL/Ruby dependencies; override MKXPZ_* for a local
# toolchain or a reproducible CI container.
set -eu
if [ -n "${CROSS_TRIPLE:-}" ] && [ -x /usr/local/bin/meson ]; then
  PATH="/usr/local/bin:$PATH"
  export PATH
fi
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
: "${MKXPZ_REPO:=https://github.com/mkxp-z/mkxp-z.git}"
: "${MKXPZ_REF:=f02d586624dc53de373889cc16d9b1516da0a3a5}"
: "${BUILD_DIR:=$ROOT/build}"
SRC="$BUILD_DIR/mkxp-z-src"
OUT="$BUILD_DIR/mkxp-z"
mkdir -p "$BUILD_DIR"
if [ -f "$SRC/leaf-source-commit" ]; then
  [ "$(cat "$SRC/leaf-source-commit")" = "$MKXPZ_REF" ] || { echo 'source revision mismatch' >&2; exit 1; }
else
  if [ ! -d "$SRC/.git" ]; then git clone "$MKXPZ_REPO" "$SRC"; fi
  git -C "$SRC" fetch --depth 1 origin "$MKXPZ_REF"
  git -C "$SRC" checkout --detach "$MKXPZ_REF"
  for patch in "$ROOT"/patches/*.patch; do
    if ! git -C "$SRC" apply --reverse --check "$patch" 2>/dev/null; then
      git -C "$SRC" apply "$patch"
    fi
  done
fi
MESON_ARGS="${MKXPZ_MESON_ARGS:-}"
if [ -n "${CROSS_TRIPLE:-}" ]; then
  CROSS_FILE="$BUILD_DIR/mlp1-cross.ini"
  cat > "$CROSS_FILE" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
ranlib = '${CROSS_ROOT}/bin/${CROSS_TRIPLE}-ranlib'
pkg-config = 'pkg-config'
[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
[properties]
sys_root = '$SYSROOT'
pkg_config_libdir = ['$SYSROOT/usr/lib/pkgconfig', '$SYSROOT/usr/share/pkgconfig']
needs_exe_wrapper = true
EOF
  cat > "$BUILD_DIR/native.ini" <<EOF
[binaries]
c = '/usr/bin/gcc'
cpp = '/usr/bin/g++'
ar = '/usr/bin/ar'
strip = '/usr/bin/strip'
EOF
  MESON_ARGS="$MESON_ARGS --cross-file $CROSS_FILE --native-file $BUILD_DIR/native.ini"
fi
if [ -f "$BUILD_DIR/mkxp-z-build/meson-private/coredata.dat" ]; then
  MESON_ARGS="$MESON_ARGS --reconfigure"
fi
meson setup "$BUILD_DIR/mkxp-z-build" "$SRC" --buildtype=release --prefix="$OUT" -Dworkdir_current=true -Dgfx_backend=gles -Ddefault_system=auto -Dangle=disabled -Djack=disabled -Dpipewire=disabled -Dpulseaudio=disabled $MESON_ARGS
meson compile -C "$BUILD_DIR/mkxp-z-build" -j "${JOBS:-4}"
meson install -C "$BUILD_DIR/mkxp-z-build"
mkdir -p "$OUT/bin"
# Upstream installs mkxp-z.aarch64; select that executable explicitly rather
# than copying a configure helper or a native build tool by mistake.
cp "$OUT/mkxp-z.aarch64" "$OUT/bin/mkxp-z"
chmod 755 "$OUT/bin/mkxp-z"
if [ -n "${STRIP:-}" ]; then "$STRIP" "$OUT/bin/mkxp-z"; fi
if [ -n "${SYSROOT:-}" ]; then
  mkdir -p "$BUILD_DIR/runtime-libs"
  cp -L "$SYSROOT/usr/lib/libfmt.so.10" "$BUILD_DIR/runtime-libs/libfmt.so.10"
  python3 "$ROOT/scripts/verify_binary.py" "$OUT/bin/mkxp-z" > "$BUILD_DIR/binary-report.json"
fi
