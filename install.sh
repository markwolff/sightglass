#!/bin/sh

set -eu

APP_NAME="Sightglass"
REPO_SLUG="${SIGHTGLASS_REPO:-markwolff/sightglass}"
REF="${SIGHTGLASS_REF:-main}"
INSTALL_ROOT="${SIGHTGLASS_INSTALL_DIR:-}"
SKIP_OPEN="${SIGHTGLASS_SKIP_OPEN:-0}"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "${TMP_DIR:-}" ]; then
    rm -rf "${TMP_DIR}"
  fi
}

trap cleanup EXIT INT TERM

[ "$(uname -s)" = "Darwin" ] || fail "This installer currently supports macOS only."
command -v curl >/dev/null 2>&1 || fail "curl is required."
command -v tar >/dev/null 2>&1 || fail "tar is required."
command -v swift >/dev/null 2>&1 || fail "swift is required. Install Xcode or the Xcode Command Line Tools first."

if [ -z "$INSTALL_ROOT" ]; then
  if [ -w /Applications ]; then
    INSTALL_ROOT="/Applications"
  else
    INSTALL_ROOT="$HOME/Applications"
  fi
fi

mkdir -p "$INSTALL_ROOT"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sightglass.XXXXXX")"
ARCHIVE_URL="https://github.com/${REPO_SLUG}/archive/refs/heads/${REF}.tar.gz"

printf 'Downloading %s source from %s\n' "$APP_NAME" "$ARCHIVE_URL"
curl -fsSL "$ARCHIVE_URL" -o "$TMP_DIR/source.tar.gz"
tar -xzf "$TMP_DIR/source.tar.gz" -C "$TMP_DIR"

SOURCE_DIR="$(find "$TMP_DIR" -maxdepth 1 -mindepth 1 -type d -name 'sightglass-*' | head -n 1)"
[ -n "$SOURCE_DIR" ] || fail "Could not locate the unpacked source directory."

cd "$SOURCE_DIR"

printf 'Building %s\n' "$APP_NAME"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path 2>/dev/null || true)"
if [ -n "$BIN_DIR" ] && [ -x "$BIN_DIR/$APP_NAME" ]; then
  EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"
else
  EXECUTABLE_PATH="$SOURCE_DIR/.build/release/$APP_NAME"
fi
[ -x "$EXECUTABLE_PATH" ] || fail "Build completed but the app binary was not found."

APP_DIR="$INSTALL_ROOT/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PROMPTS_DIR="$RESOURCES_DIR/prompts"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$PROMPTS_DIR"

cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
if [ -d "$SOURCE_DIR/Resources/prompts" ]; then
  cp "$SOURCE_DIR/Resources/prompts/"* "$PROMPTS_DIR/"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Sightglass</string>
  <key>CFBundleIdentifier</key>
  <string>com.github.markwolff.sightglass</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Sightglass</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

printf 'Installed %s to %s\n' "$APP_NAME" "$APP_DIR"

if [ "$SKIP_OPEN" != "1" ]; then
  printf 'Opening %s\n' "$APP_NAME"
  open "$APP_DIR"
fi
