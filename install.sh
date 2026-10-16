#!/usr/bin/env bash
# Openrig-Mod installer: OpenRig + Herdr + the /rig skill for Claude Code.
# Safe to run again: it skips what is already in place and backs up what it changes.
#
#   ./install.sh                 interactive install
#   ./install.sh --yes           no questions (accepts the Herdr installer and missing-tool installs)
#   ./install.sh --dry-run       print the plan, change nothing
#   ./install.sh --help          all options
set -euo pipefail

OPENRIG_VERSION="0.6.10"
AUTO_TITLE_REPO="kryptamine/herdr-auto-title"
AUTO_TITLE_REF="e78619a26674da2b741457be864169ad56767887"
HERDR_INSTALL_URL="https://herdr.dev/install.sh"

YES=0; DRY=0; DO_OPENRIG=1; DO_HERDR=1; DO_HERDR_CONFIG=1; REPLACE_HERDR_CONFIG=0
AUTO_TITLE=auto; DO_START=1; NO_KERNEL=0; INSTALL_DEPS=0; CODEX_SKILL=0; UPGRADE=0
TEST_HOME=""; PORT=""

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  --yes                    Answer yes to every question (third-party installers included).
  --dry-run                Show what would happen; change nothing.
  --install-deps           Install missing tools (Homebrew on macOS, apt on Debian/Ubuntu).
  --openrig-version V      OpenRig CLI version to install (default: tested version).
  --upgrade-openrig        Upgrade an existing, different OpenRig version (restart its daemon afterwards).
  --no-openrig             Do not install or configure OpenRig.
  --no-herdr               Do not install Herdr.
  --no-herdr-config        Do not install the Herdr config.
  --replace-herdr-config   Replace an existing Herdr config (the old one is backed up).
  --auto-title / --no-auto-title
                           Install the Herdr auto-title plugin (default: when Go is installed).
  --codex-skill            Also install /rig for Codex (~/.agents/skills).
  --no-start               Do not start the OpenRig daemon.
  --no-kernel              Start the daemon without OpenRig's kernel team.
  --home DIR               Install into DIR as if it were $HOME (for testing).
  --port N                 Daemon port (for testing next to another install).
  -h, --help               This help.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) YES=1 ;;
    --dry-run) DRY=1 ;;
    --install-deps) INSTALL_DEPS=1 ;;
    --openrig-version) OPENRIG_VERSION="$2"; shift ;;
    --upgrade-openrig) UPGRADE=1 ;;
    --no-openrig) DO_OPENRIG=0 ;;
    --no-herdr) DO_HERDR=0 ;;
    --no-herdr-config) DO_HERDR_CONFIG=0 ;;
    --replace-herdr-config) REPLACE_HERDR_CONFIG=1 ;;
    --auto-title) AUTO_TITLE=yes ;;
    --no-auto-title) AUTO_TITLE=no ;;
    --codex-skill) CODEX_SKILL=1 ;;
    --no-start) DO_START=0 ;;
    --no-kernel) NO_KERNEL=1 ;;
    --home) TEST_HOME="$2"; shift ;;
    --port) PORT="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
if [ -n "$TEST_HOME" ]; then
  mkdir -p "$TEST_HOME"; HOME=$(cd "$TEST_HOME" && pwd); export HOME
fi
STAMP=$(date +%Y%m%d-%H%M%S)
STATE_DIR="$HOME/.config/openrig-mod"
BACKUP_DIR="$STATE_DIR/backups/$STAMP"
LOG="$STATE_DIR/install-$STAMP.log"
OS=$(uname -s)

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }
step() { echo; bold "== $*"; }
log()  { [ "$DRY" = 1 ] && return 0; mkdir -p "$STATE_DIR"; printf '%s\n' "$*" >> "$LOG"; }
run()  { if [ "$DRY" = 1 ]; then info "[dry-run] $*"; else eval "$*"; fi; }
ask()  { [ "$YES" = 1 ] && return 0; [ "$DRY" = 1 ] && return 0; printf '  %s [y/N] ' "$1"; read -r a </dev/tty || a=""; case "$a" in y|Y|yes) return 0 ;; *) return 1 ;; esac; }
have() { command -v "$1" >/dev/null 2>&1; }
backup() { # backup <path>
  [ -e "$1" ] || return 0
  [ "$DRY" = 1 ] && { info "[dry-run] back up $1"; return 0; }
  mkdir -p "$BACKUP_DIR"; cp -R "$1" "$BACKUP_DIR/$(basename "$1")"
  log "backup: $1 -> $BACKUP_DIR/$(basename "$1")"
}
rc_file() { case "${SHELL:-}" in */zsh) echo "$HOME/.zshrc" ;; */bash) echo "$HOME/.bashrc" ;; *) echo "$HOME/.profile" ;; esac; }
add_path() { # add_path <dir>: put it on PATH now and in the shell rc file
  case ":$PATH:" in *":$1:"*) ;; *) export PATH="$1:$PATH" ;; esac
  local rc; rc=$(rc_file)
  if ! grep -qs "openrig-mod: $1" "$rc"; then
    run "printf '\\n# openrig-mod: $1\\nexport PATH=\"$1:\$PATH\"\\n' >> '$rc'"
    log "path: added $1 to $rc (remove the two 'openrig-mod' lines to undo)"
  fi
}

bold "Openrig-Mod installer"
info "Home: $HOME   OS: $OS   OpenRig: $OPENRIG_VERSION   $( [ "$DRY" = 1 ] && echo '(dry run)')"
log "Openrig-Mod install $STAMP (repo $REPO_DIR)"

# Earlier runs may have installed into these folders before this terminal had them on PATH.
for d in "$HOME/.npm-global/bin" "$HOME/.local/bin"; do
  [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) export PATH="$d:$PATH" ;; esac
done

# ---------------------------------------------------------------- 1. tools
step "1. Check the tools OpenRig needs"
missing=()
if have node; then
  NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
  if [ "$NODE_MAJOR" != 22 ] && [ "$NODE_MAJOR" != 24 ]; then
    warn "Node $(node --version) found; OpenRig needs Node 22 or 24 (22 recommended on Apple silicon)."; missing+=(node)
  else info "node $(node --version)"; fi
else missing+=(node); fi
for t in npm tmux git python3 curl; do if have "$t"; then info "$t ok"; else missing+=("$t"); fi; done

if [ ${#missing[@]} -gt 0 ]; then
  warn "Missing: ${missing[*]}"
  if [ "$OS" = Darwin ]; then hint="brew install node@22 tmux git python curl  (Homebrew: https://brew.sh)"
  else hint="sudo apt-get install -y tmux git python3 curl  and Node 22 from https://nodejs.org"; fi
  if [ "$INSTALL_DEPS" = 1 ] && ask "Install the missing tools now?"; then
    if [ "$OS" = Darwin ] && have brew; then
      run "brew install ${missing[*]/node/node@22}"
      [ -d "$(brew --prefix 2>/dev/null)/opt/node@22/bin" ] && add_path "$(brew --prefix)/opt/node@22/bin"
    elif have apt-get; then
      run "sudo apt-get update && sudo apt-get install -y tmux git python3 curl"
      have node || warn "Install Node 22 yourself (https://nodejs.org), then run this installer again."
    else warn "No supported package manager found. Install: $hint"; exit 1; fi
  else
    warn "Install them, then run this installer again:"; warn "  $hint"; warn "  (or rerun with --install-deps)"
    [ "$DRY" = 1 ] || exit 1
  fi
fi
if have claude; then info "Claude Code: $(claude --version 2>/dev/null | head -1)"; else warn "Claude Code not found. /rig runs inside Claude Code: https://docs.anthropic.com/claude-code"; fi
if have codex; then info "Codex: $(codex --version 2>/dev/null | head -1)"; else info "Codex not found (optional; teams can mix Claude Code and Codex)."; fi

# ---------------------------------------------------------------- 2. OpenRig
if [ "$DO_OPENRIG" = 1 ]; then
  step "2. OpenRig CLI"
  current=""; have rig && current=$(rig --version 2>/dev/null | awk '{print $1}')
  if [ "$current" = "$OPENRIG_VERSION" ]; then info "rig $current already installed"
  elif [ -n "$current" ] && [ "$UPGRADE" != 1 ]; then
    info "rig $current is installed; leaving it (use --upgrade-openrig for $OPENRIG_VERSION, then restart the daemon)."
  else
    prefix_args=""
    gprefix=$(npm prefix -g 2>/dev/null || echo "")
    use_home_prefix=0
    if [ -n "$TEST_HOME" ] || [ -z "$gprefix" ]; then use_home_prefix=1
    elif [ ! -w "$gprefix" ] && [ ! -w "$gprefix/lib" ]; then use_home_prefix=1; fi
    if [ "$use_home_prefix" = 1 ]; then
      prefix_args="--prefix $HOME/.npm-global"; add_path "$HOME/.npm-global/bin"
    fi
    run "npm install -g $prefix_args @openrig/cli@$OPENRIG_VERSION --no-fund --no-audit"
    log "openrig: installed @openrig/cli@$OPENRIG_VERSION ${prefix_args} (undo: npm uninstall -g ${prefix_args} @openrig/cli)"
    [ -n "$current" ] && warn "Restart the daemon to run the new version: rig daemon stop && rig daemon start"
  fi
  [ "$DRY" = 1 ] || rig --version >/dev/null 2>&1 || { warn "rig is not on PATH; open a new terminal and run this installer again."; exit 1; }
fi

# ---------------------------------------------------------------- 3. Herdr
if [ "$DO_HERDR" = 1 ]; then
  step "3. Herdr (terminal workspace for agents)"
  if have herdr; then info "herdr $(herdr --version 2>/dev/null | head -1) already installed; leaving it as it is"
  elif ask "Install Herdr with its official installer ($HERDR_INSTALL_URL)?"; then
    run "curl -fsSL $HERDR_INSTALL_URL | sh"
    add_path "$HOME/.local/bin"
    log "herdr: installed with $HERDR_INSTALL_URL (undo: remove ~/.local/bin/herdr)"
  else warn "Skipped Herdr. OpenRig still works; seat terminals then open in plain tmux."; fi
fi

if [ "$DO_HERDR_CONFIG" = 1 ]; then
  step "4. Herdr settings"
  HCFG="$HOME/.config/herdr/config.toml"
  if [ -f "$HCFG" ] && [ "$REPLACE_HERDR_CONFIG" != 1 ]; then
    info "Keeping your existing $HCFG (use --replace-herdr-config to use the shipped one; it would be backed up)."
  else
    backup "$HCFG"
    run "mkdir -p '$HOME/.config/herdr' && cp '$REPO_DIR/herdr/config.toml' '$HCFG'"
    log "herdr config: installed $HCFG"
  fi
  if have herdr && [ "$DRY" != 1 ]; then herdr config check 2>&1 | sed 's/^/  /' || true; fi
  want_at=0
  case "$AUTO_TITLE" in yes) want_at=1 ;; auto) have go && want_at=1 ;; esac
  if [ "$want_at" = 1 ] && have herdr; then
    if have go; then
      run "herdr plugin install $AUTO_TITLE_REPO --ref $AUTO_TITLE_REF --yes" || warn "auto-title plugin install failed; Herdr works without it."
      log "herdr plugin: $AUTO_TITLE_REPO@$AUTO_TITLE_REF (undo: herdr plugin uninstall herdr.auto-title)"
    else warn "The auto-title plugin needs Go (brew install go). Skipped."; fi
  fi
fi

# ---------------------------------------------------------------- 5. the /rig skill
step "5. The /rig skill for Claude Code"
install_skill() { # install_skill <skills dir>
  local dest="$1/rig"
  if [ -d "$dest" ]; then
    if diff -rq "$REPO_DIR/skill/rig" "$dest" >/dev/null 2>&1; then info "$dest is up to date"; return 0; fi
    backup "$dest"; run "rm -rf '$dest'"
  fi
  run "mkdir -p '$1' && cp -R '$REPO_DIR/skill/rig' '$dest' && chmod +x '$dest/scripts/'*"
  log "skill: installed $dest (undo: remove $dest)"; [ "$DRY" = 1 ] || info "installed $dest"
}
install_skill "$HOME/.claude/skills"
[ "$CODEX_SKILL" = 1 ] && install_skill "$HOME/.agents/skills"

# Hide OpenRig's own `rigs` skill in Claude Code: the daemon restores it on every
# upgrade, so a setting is the durable way to keep one /rig entry point.
SETTINGS="$HOME/.claude/settings.json"
if [ "$DRY" = 1 ]; then info "[dry-run] add \"skillOverrides\": {\"rigs\": \"off\"} to $SETTINGS"
else
  mkdir -p "$HOME/.claude"; [ -f "$SETTINGS" ] && backup "$SETTINGS"
  python3 -I - "$SETTINGS" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
if not p.exists() or not p.read_text().strip():
    p.write_text('{\n  "skillOverrides": {"rigs": "off"}\n}\n'); print("  created", p); sys.exit(0)
raw = p.read_text(); d = json.loads(raw)
so = d.get("skillOverrides")
if isinstance(so, dict) and so.get("rigs") == "off":
    print("  rigs already hidden"); sys.exit(0)
if isinstance(so, dict):
    so["rigs"] = "off"; p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
else:
    body = raw.rstrip(); assert body.endswith("}")
    inner = body[:-1].rstrip()
    sep = "" if inner.endswith("{") else ","
    p.write_text(inner + sep + '\n  "skillOverrides": {"rigs": "off"}\n}\n')
json.loads(p.read_text())
print("  hid the duplicate 'rigs' skill in", p)
PY
  log "settings: skillOverrides.rigs=off in $SETTINGS (undo: remove that key, or restore the backup)"
fi

NOTES="$STATE_DIR/machine-notes.md"
if [ -f "$NOTES" ]; then info "keeping $NOTES"
else
  run "mkdir -p '$STATE_DIR' && cp '$REPO_DIR/skill/rig/references/machine-notes-template.md' '$NOTES'"
  log "notes: created $NOTES"; [ "$DRY" = 1 ] || info "created $NOTES (your local preferences and learned facts)"
fi

# ---------------------------------------------------------------- 6. OpenRig settings
if [ "$DO_OPENRIG" = 1 ] && [ "$DRY" != 1 ] && have rig; then
  step "6. OpenRig settings"
  set_default() { # set_default <key> <value>: only when the key still has its default
    if rig config --with-source 2>/dev/null | grep -E "^$1 " | grep -q "source: default"; then
      rig config set "$1" "$2" >/dev/null && info "$1 = $2" && log "config: $1=$2 (undo: rig config reset $1)"
    else info "$1 already set; kept"; fi
  }
  set_default health.context_pressure.warning_percent 80
  set_default health.context_pressure.critical_percent 90
  tz=""
  if [ -L /etc/localtime ]; then tz=$(readlink /etc/localtime | sed 's#.*zoneinfo/##'); fi
  [ -z "$tz" ] && [ -f /etc/timezone ] && tz=$(cat /etc/timezone)
  [ -n "$tz" ] && set_default ui.timezone "$tz"
  set_default host.name "$(hostname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo this-machine)"
fi

# ---------------------------------------------------------------- 7. daemon
if [ "$DO_OPENRIG" = 1 ] && [ "$DO_START" = 1 ]; then
  step "7. OpenRig daemon"
  if [ -n "$PORT" ] && [ "$DRY" != 1 ]; then rig config set daemon.port "$PORT" >/dev/null; log "config: daemon.port=$PORT (undo: rig config reset daemon.port)"; fi
  if [ "$DRY" = 1 ]; then info "[dry-run] rig daemon start"
  elif rig daemon status 2>/dev/null | grep -qi running; then info "$(rig daemon status 2>/dev/null | head -1)"
  else
    args=""; [ "$NO_KERNEL" = 1 ] && args="$args --no-kernel"; [ -n "$PORT" ] && args="$args --port $PORT"
    nohup rig daemon start $args >"$STATE_DIR/daemon-start.log" 2>&1 </dev/null || true
    rig daemon status 2>&1 | head -1 | sed 's/^/  /'
    log "daemon: started (stop with: rig daemon stop)"
  fi
fi

# ---------------------------------------------------------------- done
step "Done"
[ "$DRY" = 1 ] || info "Install log with undo steps: $LOG"
cat <<'EOF'

  Next steps
  1. Open a new terminal (so PATH changes apply) and start Herdr:   herdr
  2. Sign in to your agents if you have not:   claude   (and/or: codex login)
  3. In Herdr, run the dashboard in one pane:   rig tui
     and Claude Code in a second pane:          claude
  4. In Claude Code, type:   /rig what can you do?
     Then describe what you want, for example:
       /rig set up a small team to add tests to ~/src/myapp
EOF
