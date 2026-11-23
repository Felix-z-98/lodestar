#!/bin/sh
# Lodestar installer for Linux. Installs for the current user only; never asks for a password.
#
#   curl -fsSL https://raw.githubusercontent.com/Felix-z-98/lodestar/main/install.sh | sh
#
# Run it again to update. Options (after "sh -s --" when piping):
#   --no-helpers   skip Legendary (Epic), umu-run (Windows games) and Ludusavi (saves)
#   --uninstall    remove Lodestar (settings, games and saves are kept)
#
# Everything goes under ~/.local/share/lodestar2, plus a "lodestar" command in ~/.local/bin and
# an app-menu entry. Each download is checked against a known SHA-256 before it is used.
set -eu

REPO="Felix-z-98/lodestar"
ELECTRON="45.3.1"
LEGENDARY="0.21.1"
UMU="1.4.4"
LUDUSAVI="0.31.0"

# Known SHA-256 of every outside download.
SUM_ELECTRON_x64="c61d44206f8bd533d30310840b5baaa7fd0e8421cd711b8d1f719a7a336cbce7"
SUM_ELECTRON_arm64="98bb5dbdcd5c6daaba6d2de293fe84bfae0ba61eb4288042a13723cf865b060a"
SUM_LEGENDARY_x64="dbed33bbe96031e65858233e4badf0a1d401bb6cb0cc995d1237cf3a0c826a45"
SUM_LEGENDARY_arm64="e901cb52ada10d5cef6ffb2a0985099958124457bfb455a571023d1e042143d9"
SUM_UMU="eb590691841f7fad3fc3ad8fd5db4ccb87849fe7948e62b28ece7a4ee48cc851"
SUM_LUDUSAVI_x64="7322ff45d41eae7ae064a80d8c9ecccc5b8fb6fc090a603a66369cd4b054068d"

ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/lodestar2"
BIN="$HOME/.local/bin"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
# For testing: a local package file, or another place to download the package from.
PACKAGE="${LODESTAR_PACKAGE:-}"
BASE="${LODESTAR_BASE_URL:-https://github.com/$REPO/releases/latest/download}"

HELPERS=1
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --no-helpers) HELPERS=0 ;;
    --uninstall) UNINSTALL=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'Lodestar installer: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

if [ "$UNINSTALL" = 1 ]; then
  rm -rf "$ROOT/app" "$ROOT/tools" "$ROOT"/electron-*
  rm -f "$BIN/lodestar" "$APPS/lodestar.desktop" "$ICONS/lodestar.svg"
  rmdir "$ROOT" 2>/dev/null || true
  say "Lodestar is removed."
  say "Kept: your settings and themes (~/.config/Lodestar2), and any games, sign-ins and"
  say "game data under $ROOT. Delete those folders yourself if you want them gone."
  exit 0
fi

[ "$(uname -s)" = Linux ] || die "this installer is for Linux."
case "$(uname -m)" in
  x86_64|amd64) ARCH=x64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) die "unsupported processor: $(uname -m)" ;;
esac
have sha256sum || die "sha256sum is missing (it is part of coreutils)."
have tar || die "tar is missing."
if have curl; then fetch() { curl -fL --retry 3 --progress-bar -o "$2" "$1"; }
elif have wget; then fetch() { wget -q --show-progress -O "$2" "$1"; }
else die "curl or wget is needed to download."
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

check() { # file, expected sum, name
  got="$(sha256sum "$1" | cut -d' ' -f1)"
  [ "$got" = "$2" ] || die "$3 did not match its checksum (download damaged or changed). Nothing was installed from it."
}
unzip_to() { # zip, folder
  mkdir -p "$2"
  if have unzip; then unzip -q "$1" -d "$2"
  elif have bsdtar; then bsdtar -xf "$1" -C "$2"
  elif have python3; then
    python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$1" "$2"
    chmod +x "$2/electron" "$2/chrome-sandbox" "$2/chrome_crashpad_handler" 2>/dev/null || true
  else die "unzip is needed (install the 'unzip' package)."
  fi
}

mkdir -p "$ROOT" "$BIN" "$APPS" "$ICONS"

# ---- 1. the app itself ----
say "Lodestar: fetching the app..."
if [ -n "$PACKAGE" ]; then
  cp "$PACKAGE" "$TMP/lodestar.tar.gz"
else
  fetch "$BASE/lodestar.tar.gz" "$TMP/lodestar.tar.gz"
  fetch "$BASE/lodestar.tar.gz.sha256" "$TMP/lodestar.sum"
  check "$TMP/lodestar.tar.gz" "$(cut -d' ' -f1 "$TMP/lodestar.sum")" "The Lodestar package"
fi
mkdir "$TMP/app"
tar -xzf "$TMP/lodestar.tar.gz" -C "$TMP/app" --strip-components=1
[ -f "$TMP/app/package.json" ] && [ -f "$TMP/app/src/main.js" ] || die "the package is not a Lodestar package."
VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$TMP/app/package.json" | head -n 1)"

# ---- 2. Electron, the program that runs it (only when this version is not here yet) ----
EDIR="$ROOT/electron-$ELECTRON"
if [ ! -x "$EDIR/electron" ]; then
  say "Lodestar: fetching Electron $ELECTRON (about 110 MB, first time only)..."
  fetch "https://github.com/electron/electron/releases/download/v$ELECTRON/electron-v$ELECTRON-linux-$ARCH.zip" "$TMP/electron.zip"
  eval "want=\$SUM_ELECTRON_$ARCH"
  check "$TMP/electron.zip" "$want" "Electron"
  unzip_to "$TMP/electron.zip" "$TMP/electron"
  [ -x "$TMP/electron/electron" ] || die "Electron did not unpack properly."
  rm -rf "$EDIR"
  mv "$TMP/electron" "$EDIR"
fi
for old in "$ROOT"/electron-*; do
  [ "$old" = "$EDIR" ] || rm -rf "$old"
done

# Swap the app in only once everything it needs is in place.
rm -rf "$ROOT/app.old"
[ -d "$ROOT/app" ] && mv "$ROOT/app" "$ROOT/app.old"
mv "$TMP/app" "$ROOT/app"
rm -rf "$ROOT/app.old"

# ---- 3. helpers (each one is optional; a failed helper does not stop the install) ----
helper() { # name, url, sum, what it is for
  if fetch "$2" "$TMP/$1.dl" && [ "$(sha256sum "$TMP/$1.dl" | cut -d' ' -f1)" = "$3" ]; then return 0; fi
  say "  Could not fetch $1 ($4 will not work until it is installed). Carrying on."
  return 1
}
if [ "$HELPERS" = 1 ]; then
  mkdir -p "$ROOT/tools"
  if [ ! -x "$ROOT/tools/legendary" ] && ! have legendary; then
    say "Lodestar: fetching Legendary $LEGENDARY (for Epic Games)..."
    eval "want=\$SUM_LEGENDARY_$ARCH"
    if helper legendary "https://github.com/derrod/legendary/releases/download/$LEGENDARY/legendary_linux_$ARCH" "$want" "Epic Games"; then
      mv "$TMP/legendary.dl" "$ROOT/tools/legendary"; chmod +x "$ROOT/tools/legendary"
    fi
  fi
  if [ ! -x "$ROOT/tools/umu-run" ] && ! have umu-run; then
    say "Lodestar: fetching umu-run $UMU (starts Windows games from GOG and Epic)..."
    if helper umu "https://github.com/Open-Wine-Components/umu-launcher/releases/download/$UMU/umu-launcher-$UMU-zipapp.tar" "$SUM_UMU" "Windows games from GOG and Epic"; then
      mkdir "$TMP/umu" && tar -xf "$TMP/umu.dl" -C "$TMP/umu"
      mv "$TMP/umu/umu/umu-run" "$ROOT/tools/umu-run"; chmod +x "$ROOT/tools/umu-run"
      have python3 || say "  Note: umu-run needs python3, which is not installed here."
    fi
  fi
  if [ "$ARCH" = x64 ] && [ ! -x "$ROOT/tools/ludusavi" ] && ! have ludusavi; then
    say "Lodestar: fetching Ludusavi $LUDUSAVI (finds your game saves)..."
    if helper ludusavi "https://github.com/mtkennerly/ludusavi/releases/download/v$LUDUSAVI/ludusavi-v$LUDUSAVI-linux.tar.gz" "$SUM_LUDUSAVI_x64" "Finding saves of non-Steam games"; then
      mkdir "$TMP/ludusavi" && tar -xzf "$TMP/ludusavi.dl" -C "$TMP/ludusavi"
      mv "$TMP/ludusavi/ludusavi" "$ROOT/tools/ludusavi"; chmod +x "$ROOT/tools/ludusavi"
    fi
  fi
fi

# ---- 4. the "lodestar" command, the app-menu entry and the icon ----
cat > "$BIN/lodestar" <<EOF
#!/bin/sh
# Starts Lodestar. "lodestar --update" fetches the newest version, "lodestar --uninstall" removes it.
ROOT="$ROOT"
INSTALLER="https://raw.githubusercontent.com/$REPO/main/install.sh"
case "\${1:-}" in
  --update|--uninstall)
    if command -v curl >/dev/null 2>&1; then curl -fsSL "\$INSTALLER" -o "\$ROOT/install.sh"
    else wget -qO "\$ROOT/install.sh" "\$INSTALLER"; fi || { echo "Could not reach the download page." >&2; exit 1; }
    [ "\$1" = --uninstall ] && exec sh "\$ROOT/install.sh" --uninstall
    exec sh "\$ROOT/install.sh"
    ;;
esac
# Some systems (Ubuntu 24.04 and later) stop programs from making their own sandbox. Electron
# refuses to start there unless told to go without it.
FLAGS=""
if [ "\$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" = 1 ] ||
   [ "\$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null)" = 0 ]; then
  FLAGS="--no-sandbox"
fi
exec "\$ROOT/electron-$ELECTRON/electron" \$FLAGS "\$ROOT/app" "\$@"
EOF
chmod +x "$BIN/lodestar"

cp "$ROOT/app/assets/icon.svg" "$ICONS/lodestar.svg"
cat > "$APPS/lodestar.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Lodestar
Comment=Customizable game launcher
Exec="$BIN/lodestar"
Icon=lodestar
Categories=Game;
Terminal=false
EOF
have update-desktop-database && update-desktop-database "$APPS" >/dev/null 2>&1 || true

say ""
say "Lodestar ${VERSION:-} is installed."
say "  Start it from your app menu, or run: lodestar"
say "  Update later with: lodestar --update"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) say "  ($BIN is not on your PATH, so in a terminal use: $BIN/lodestar)" ;;
esac
