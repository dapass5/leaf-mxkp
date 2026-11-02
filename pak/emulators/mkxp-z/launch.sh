#!/bin/sh
set -eu
SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BIN="$SELF_DIR/bin/mkxp-z"
LD_LIBRARY_PATH="$SELF_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH
MKXPZ_LEAF_FULLSCREEN=1
export MKXPZ_LEAF_FULLSCREEN
GAME="${1:-}"
fail() { echo "mkxp-z: $*" >&2; exit 2; }
[ -x "$BIN" ] || fail "missing executable: $BIN"
[ -n "$GAME" ] || fail "no game path supplied"
case "$GAME" in /*) ;; *) fail "game path must be absolute: $GAME" ;; esac
for name in USERDATA_PATH SAVES_PATH LOGS_PATH ROMS_PATH; do
    eval "value=\${$name:-}"
    [ -n "$value" ] || fail "$name is not set; run this from Leaf"
done
if [ -d "$GAME" ]; then GAME_DIR="$GAME"; else
    [ -f "$GAME" ] || fail "game path is not a file or directory: $GAME"
    GAME_DIR="$(CDPATH= cd -- "$(dirname -- "$GAME")" && pwd -P)"
fi
GAME_DIR="$(CDPATH= cd -- "$GAME_DIR" && pwd -P)"
ROM_ROOT="$(CDPATH= cd -- "$ROMS_PATH" && pwd -P)"
case "$GAME_DIR" in
    "$ROM_ROOT"/*) RELATIVE_GAME="${GAME_DIR#"$ROM_ROOT"/}" ;;
    *) fail "game must be below ROMS_PATH" ;;
esac
GAME_KEY="$(printf '%s' "$RELATIVE_GAME" | cksum | awk '{print $1 "-" $2}')"
RUN_DIR="$USERDATA_PATH/mkxp-z/$GAME_KEY"
mkdir -p "$RUN_DIR" "$SAVES_PATH/mkxp-z/$GAME_KEY" "$LOGS_PATH" || fail "cannot create runtime directories"
MKXPZ_LEAF_KEYMAP=""
# Resolve afresh at every launch; the game's profile takes precedence over
# the old userdata location so existing installations can migrate gradually.
if [ -f "$GAME_DIR/controller.keys" ]; then
    MKXPZ_LEAF_KEYMAP="$GAME_DIR/controller.keys"
elif [ -f "$RUN_DIR/controller.keys" ]; then
    MKXPZ_LEAF_KEYMAP="$RUN_DIR/controller.keys"
fi
export MKXPZ_LEAF_KEYMAP
# Native frame timing is opt-in per game and stops after four minutes.
MKXPZ_LEAF_FRAME_TRACE=""
[ ! -f "$RUN_DIR/frame-trace.enabled" ] || MKXPZ_LEAF_FRAME_TRACE="$RUN_DIR/leaf-frame-trace.csv"
export MKXPZ_LEAF_FRAME_TRACE
# SDL_GetPrefPath interprets org/app as names, not absolute paths.
XDG_DATA_HOME="$SAVES_PATH"
export XDG_DATA_HOME
json_path() {
    # Reject control characters, then escape paths for a JSON string.
    [ "$(printf '%s' "$1" | LC_ALL=C tr -d '\000-\037' | wc -c)" = "$(printf '%s' "$1" | wc -c)" ] || fail "control character in path"
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}
GAME_JSON="$(json_path "$GAME_DIR")"
STDLIB_JSON="$(json_path "$SELF_DIR/stdlib")"
MKXPZ_LEAF_GAME_CONFIG="$GAME_DIR/mkxp.json"
export MKXPZ_LEAF_GAME_CONFIG
cat > "$RUN_DIR/mkxp.json" <<EOF
{
  "gameFolder": "$GAME_JSON",
  "dataPathOrg": "mkxp-z",
  "dataPathApp": "$GAME_KEY",
  "rubyLoadpath": ["$STDLIB_JSON", "$STDLIB_JSON/aarch64-linux", "$GAME_JSON"],
  "fullscreen": true,
  "vsync": true
}
EOF
cd "$RUN_DIR"
if [ "${MKXPZ_DRY_RUN:-0}" = "1" ]; then
    printf '%s\n' "$BIN" "$RUN_DIR/mkxp.json" "$GAME_DIR"
    exit 0
fi
exec "$BIN" "$GAME_DIR" >>"$LOGS_PATH/mkxp-z.log" 2>&1
