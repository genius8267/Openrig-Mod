#!/usr/bin/env bash
# Openrig-Mod uninstaller: takes back what install.sh added.
# It moves files into an archive folder instead of deleting them.
#
#   ./uninstall.sh             remove the /rig skill, the Claude Code setting, the PATH lines
#                              and the Herdr config (only when you did not change it)
#   ./uninstall.sh --all       also stop the daemon and remove the OpenRig CLI and the auto-title plugin
#   ./uninstall.sh --dry-run   show what would happen; change nothing
set -euo pipefail

ALL=0; DRY=0; YES=0; TEST_HOME=""

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [options]

  --all          Also stop the OpenRig daemon and remove the OpenRig CLI and the
                 Herdr auto-title plugin. Your rigs and history in ~/.openrig stay.
  --yes          Do not ask for confirmation.
  --dry-run      Show what would happen; change nothing.
  --home DIR     Act on DIR as if it were $HOME (for testing).
  -h, --help     This help.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --all) ALL=1 ;;
    --yes|-y) YES=1 ;;
    --dry-run) DRY=1 ;;
    --home) TEST_HOME="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
if [ -n "$TEST_HOME" ]; then HOME=$(cd "$TEST_HOME" && pwd); export HOME; fi
STAMP=$(date +%Y%m%d-%H%M%S)
STATE_DIR="$HOME/.config/openrig-mod"
ARCHIVE="$STATE_DIR/uninstalled/$STAMP"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }
step() { echo; bold "== $*"; }
have() { command -v "$1" >/dev/null 2>&1; }
# Earlier installs may have used these folders before this terminal had them on PATH.
for d in "$HOME/.npm-global/bin" "$HOME/.local/bin"; do
  [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) export PATH="$d:$PATH" ;; esac
done
archive_path() { printf '%s/%s' "$ARCHIVE" "$(printf '%s' "${1#"$HOME"/}" | tr '/' '_')"; }
move_aside() { # move_aside <path>: move it into the archive folder
  [ -e "$1" ] || return 0
  if [ "$DRY" = 1 ]; then info "[dry-run] move $1 into $ARCHIVE"; return 0; fi
  mkdir -p "$ARCHIVE"; mv "$1" "$(archive_path "$1")"; info "moved $1 into $ARCHIVE"
}
keep_copy() { # keep_copy <file>: copy it into the archive folder before an edit
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$ARCHIVE"; cp "$1" "$(archive_path "$1")"
}

bold "Openrig-Mod uninstaller"
info "Home: $HOME   $( [ "$ALL" = 1 ] && echo 'mode: --all')   $( [ "$DRY" = 1 ] && echo '(dry run)')"
if [ "$YES" != 1 ] && [ "$DRY" != 1 ]; then
  printf '  Continue? [y/N] '; read -r a </dev/tty || a=""
  case "$a" in y|Y|yes) ;; *) echo "  Nothing changed."; exit 0 ;; esac
fi

# ---------------------------------------------------------------- 1. skill
step "1. The /rig skill"
for d in "$HOME/.claude/skills/rig" "$HOME/.agents/skills/rig"; do
  [ -d "$d" ] || continue
  if grep -qs "openrig-mod/machine-notes.md" "$d/SKILL.md"; then move_aside "$d"
  else info "$d is not the Openrig-Mod version; left in place"; fi
done

# ---------------------------------------------------------------- 2. Claude Code setting
step "2. Claude Code setting (skillOverrides.rigs)"
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ] && grep -qs '"skillOverrides"' "$SETTINGS"; then
  keep_copy "$SETTINGS"
  DRY="$DRY" python3 -I - "$SETTINGS" <<'PY'
import json, os, pathlib, re, sys
p = pathlib.Path(sys.argv[1]); raw = p.read_text(); d = json.loads(raw)
so = d.get("skillOverrides")
if not (isinstance(so, dict) and so.get("rigs") == "off"):
    print("  rigs is not hidden by this setting; nothing to change"); sys.exit(0)
if os.environ.get("DRY") == "1":
    print("  [dry-run] remove skillOverrides.rigs from", p); sys.exit(0)
# Keep the file's own formatting when the key is exactly what install.sh added.
new = re.sub(r',\s*"skillOverrides"\s*:\s*\{\s*"rigs"\s*:\s*"off"\s*\}', "", raw, count=1)
try:
    ok = new != raw and "skillOverrides" not in json.loads(new)
except ValueError:
    ok = False
if not ok:
    del so["rigs"]
    if not so:
        del d["skillOverrides"]
    new = json.dumps(d, indent=2, ensure_ascii=False) + "\n"
json.loads(new)
p.write_text(new)
print("  OpenRig's own 'rigs' skill shows again in", p)
PY
else info "no skillOverrides in $SETTINGS; nothing to change"; fi

# ---------------------------------------------------------------- 3. PATH lines
step "3. PATH lines in shell startup files"
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile"; do
  grep -qs "^# openrig-mod: " "$rc" || continue
  if [ "$DRY" = 1 ]; then info "[dry-run] remove the openrig-mod PATH lines from $rc"; continue; fi
  keep_copy "$rc"
  python3 -I - "$rc" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); lines = p.read_text().split("\n"); out = []; i = 0
while i < len(lines):
    if lines[i].startswith("# openrig-mod: "):
        if out and out[-1] == "":
            out.pop()
        i += 2 if i + 1 < len(lines) and lines[i + 1].startswith("export PATH=") else 1
        continue
    out.append(lines[i]); i += 1
p.write_text("\n".join(out))
print("  removed the openrig-mod PATH lines from", p)
PY
done

# ---------------------------------------------------------------- 4. Herdr config
step "4. Herdr settings"
HCFG="$HOME/.config/herdr/config.toml"
if [ -f "$HCFG" ] && cmp -s "$HCFG" "$REPO_DIR/herdr/config.toml"; then
  prev=""
  for b in "$STATE_DIR"/backups/*/config.toml; do [ -f "$b" ] && prev="$b"; done
  move_aside "$HCFG"
  if [ -n "$prev" ]; then
    if [ "$DRY" = 1 ]; then info "[dry-run] restore your earlier Herdr config from $prev"
    else cp "$prev" "$HCFG"; info "restored your earlier Herdr config from $prev"; fi
  else info "Herdr now uses its built-in settings"; fi
elif [ -f "$HCFG" ]; then info "$HCFG differs from the shipped one (yours or changed); left in place"
else info "no Herdr config; nothing to change"; fi

# ---------------------------------------------------------------- 5. --all
if [ "$ALL" = 1 ]; then
  step "5. OpenRig CLI and the auto-title plugin"
  if have herdr && herdr plugin list 2>/dev/null | grep -q "herdr.auto-title"; then
    if [ "$DRY" = 1 ]; then info "[dry-run] herdr plugin uninstall herdr.auto-title"
    else herdr plugin uninstall herdr.auto-title || warn "could not remove the auto-title plugin"; fi
  fi
  if have rig; then
    if [ "$DRY" = 1 ]; then info "[dry-run] rig daemon stop"
    else rig daemon stop 2>&1 | head -1 | sed 's/^/  /' || true; fi
  fi
  prefix_args=""
  [ -d "$HOME/.npm-global/lib/node_modules/@openrig/cli" ] && prefix_args="--prefix $HOME/.npm-global"
  if have npm; then
    if [ "$DRY" = 1 ]; then info "[dry-run] npm uninstall -g $prefix_args @openrig/cli"
    else
      # shellcheck disable=SC2086
      npm uninstall -g $prefix_args @openrig/cli --no-fund --no-audit 2>&1 | tail -1 | sed 's/^/  /'
    fi
  fi
  if grep -qs "^herdr: installed" "$STATE_DIR"/install-*.log; then
    info "The installer also installed Herdr. To remove it: rm ~/.local/bin/herdr"
  fi
  info "Your OpenRig data stays in ~/.openrig (rigs, history, settings). Move it away yourself if you want it gone."
  info "OpenRig's own skills in ~/.claude/skills (openrig-skills, refocusing, rigs) stay. The OpenRig daemon put them there."
fi

step "Done"
[ "$DRY" = 1 ] || { [ -d "$ARCHIVE" ] && info "Moved and edited files are kept in $ARCHIVE"; }
info "Your machine notes stay in $STATE_DIR/machine-notes.md."
info "Open a new terminal so the PATH change applies."
