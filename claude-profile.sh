#!/usr/bin/env bash
# Claude Desktop Profiles - macOS version (EXPERIMENTAL, community-tested only)
#
# Run several Claude Desktop accounts side by side on macOS. Each profile is a
# separate Claude instance with its own data folder (login, settings, history),
# opened from its own launcher app with a recolored icon.
#
# Unofficial workaround - not affiliated with or supported by Anthropic.
#
# Usage:
#   ./claude-profile.sh install   <Name> [color]      # color: red orange yellow green teal blue indigo purple pink, or hue 0-360
#   ./claude-profile.sh launch    <Name> [claude://url]
#   ./claude-profile.sh list
#   ./claude-profile.sh uninstall <Name> [--remove-data]
#
# Note: macOS ships bash 3.2, so this script avoids bash 4+ features.

set -euo pipefail

ROOT="$HOME/Library/Application Support/ClaudeProfiles"
APPS_DIR="$HOME/Applications"
SCRIPT_COPY="$ROOT/claude-profile.sh"
SOURCE_HUE=15   # approximate hue of Claude's orange, used to compute the rotation

die()   { echo "Error: $*" >&2; exit 1; }
usage() { sed -n '10,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

check_name() {
  [[ "${1:-}" =~ ^[A-Za-z0-9_-]+$ ]] || die "Profile name must use only letters, numbers, - and _"
}

find_claude() {
  local app
  for app in "/Applications/Claude.app" "$HOME/Applications/Claude.app"; do
    [[ -d "$app" ]] && { echo "$app"; return; }
  done
  app="$(mdfind "kMDItemFSName == 'Claude.app' && kMDItemContentType == 'com.apple.application-bundle'" 2>/dev/null | head -n 1)"
  [[ -n "$app" ]] && { echo "$app"; return; }
  die "Claude.app not found. Install Claude Desktop from https://claude.ai/download first."
}

color_to_hue() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    red) echo 0 ;; orange) echo 25 ;; yellow) echo 50 ;; green) echo 140 ;; teal) echo 180 ;;
    blue) echo 210 ;; indigo) echo 240 ;; purple) echo 270 ;; pink) echo 330 ;;
    *) [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]] && echo "$1" ||
         die "Unknown color '$1'. Use red, orange, yellow, green, teal, blue, indigo, purple, pink, or a hue 0-360." ;;
  esac
}

data_dir()     { echo "$HOME/Library/Application Support/Claude-$1"; }
launcher_app() { echo "$APPS_DIR/Claude ($1).app"; }

profile_running() {
  pgrep -f -- "--user-data-dir=$(data_dir "$1")( |$)" >/dev/null 2>&1
}

# Rotate the hue of a PNG with Core Image (built into macOS, no installs needed).
hue_rotate_png() {   # in out degrees
  osascript -l JavaScript - "$1" "$2" "$3" <<'JXA'
ObjC.import('AppKit');
ObjC.import('QuartzCore');
function run(argv) {
  var img = $.CIImage.imageWithContentsOfURL($.NSURL.fileURLWithPath(argv[0]));
  var f = $.CIFilter.filterWithName('CIHueAdjust');
  f.setValueForKey(img, 'inputImage');
  f.setValueForKey($.NSNumber.numberWithDouble(parseFloat(argv[2]) * Math.PI / 180), 'inputAngle');
  var rep = $.NSBitmapImageRep.alloc.initWithCIImage(f.valueForKey('outputImage'));
  var png = rep.representationUsingTypeProperties(4 /* PNG */, $({}));
  if (!png.writeToFileAtomically(argv[1], true)) throw new Error('could not write ' + argv[1]);
}
JXA
}

make_icns() {   # claude_app hue out.icns
  local claude="$1" hue="$2" out="$3" tmp icon_name icon_file rot
  tmp="$(mktemp -d)"
  icon_name="$(defaults read "$claude/Contents/Info" CFBundleIconFile 2>/dev/null || echo AppIcon)"
  icon_file="$claude/Contents/Resources/${icon_name%.icns}.icns"
  [[ -f "$icon_file" ]] || die "Could not find Claude's icon at $icon_file"

  sips -s format png "$icon_file" --out "$tmp/base.png" >/dev/null
  sips -z 1024 1024 "$tmp/base.png" >/dev/null
  rot="$(awk -v t="$hue" -v s="$SOURCE_HUE" 'BEGIN { print t - s }')"
  hue_rotate_png "$tmp/base.png" "$tmp/tinted.png" "$rot"

  mkdir -p "$tmp/icon.iconset"
  local s
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$tmp/tinted.png" --out "$tmp/icon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$tmp/tinted.png" --out "$tmp/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$tmp/icon.iconset" -o "$out"
  rm -rf "$tmp"
}

cmd_install() {
  local name="${1:-}" color="${2:-blue}" hue claude bid app data
  check_name "$name"
  hue="$(color_to_hue "$color")"
  claude="$(find_claude)"
  bid="$(defaults read "$claude/Contents/Info" CFBundleIdentifier)"
  app="$(launcher_app "$name")"
  data="$(data_dir "$name")"

  mkdir -p "$ROOT/$name" "$APPS_DIR"
  [[ "$0" -ef "$SCRIPT_COPY" ]] || cp "$0" "$SCRIPT_COPY"
  chmod +x "$SCRIPT_COPY"

  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Claude ($name)</string>
  <key>CFBundleDisplayName</key><string>Claude ($name)</string>
  <key>CFBundleIdentifier</key><string>local.claudeprofiles.$name</string>
  <key>CFBundleExecutable</key><string>launcher</string>
  <key>CFBundleIconFile</key><string>icon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
  cat > "$app/Contents/MacOS/launcher" <<LAUNCHER
#!/bin/bash
exec open -n -b "$bid" --args --user-data-dir="$data"
LAUNCHER
  chmod +x "$app/Contents/MacOS/launcher"

  make_icns "$claude" "$hue" "$app/Contents/Resources/icon.icns"
  touch "$app"

  echo "Profile '$name' installed."
  echo "  Launcher : $app"
  echo "  Data     : $data"
  echo "Open it from Spotlight/Launchpad (\"Claude ($name)\") or drag it to the Dock,"
  echo "then sign in with 'Continue with email' and type the code (see README)."
}

cmd_launch() {
  local name="${1:-}" url="${2:-}" claude bid
  check_name "$name"
  claude="$(find_claude)"
  bid="$(defaults read "$claude/Contents/Info" CFBundleIdentifier)"
  if [[ -n "$url" ]]; then
    open -n -b "$bid" --args --user-data-dir="$(data_dir "$name")" "$url"
  else
    open -n -b "$bid" --args --user-data-dir="$(data_dir "$name")"
  fi
}

cmd_list() {
  [[ -d "$ROOT" ]] || { echo "No profiles installed."; return; }
  local d n
  for d in "$ROOT"/*/; do
    [[ -d "$d" ]] || continue
    n="$(basename "$d")"
    if profile_running "$n"; then echo "$n  (running)"; else echo "$n"; fi
  done
}

cmd_uninstall() {
  local name="${1:-}" flag="${2:-}" data
  check_name "$name"
  profile_running "$name" && die "Quit the Claude ($name) window first."
  rm -rf "$(launcher_app "$name")" "$ROOT/$name"
  echo "Removed launcher for '$name'."
  if [[ "$flag" == "--remove-data" ]]; then
    data="$(data_dir "$name")"
    rm -rf "$data"
    echo "Deleted $data"
  else
    echo "Login data kept (re-install with the same name to reuse it, or add --remove-data)."
  fi
}

[[ "$(uname -s)" == "Darwin" ]] || die "This is the macOS version. On Windows use claude-profile.ps1."

case "${1:-}" in
  install)   shift; cmd_install "$@" ;;
  launch)    shift; cmd_launch "$@" ;;
  list)      cmd_list ;;
  uninstall) shift; cmd_uninstall "$@" ;;
  *)         usage ;;
esac
