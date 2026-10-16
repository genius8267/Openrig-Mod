# Troubleshooting

First try `/rig` with no words. It checks every online machine, fixes most of the problems below by itself and tells you what is left.

## Install

**`rig: command not found` after the install.**
Open a new terminal. The installer added the PATH lines to your shell startup file, and only new terminals read them. For the current terminal: `export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"`

**`/rig` does not show in Claude Code.**
Start Claude Code again. Check that `~/.claude/skills/rig/SKILL.md` exists. If it does not, run `./install.sh` again.

**Claude Code shows both `rig` and `rigs`.**
`rigs` is OpenRig's built-in skill. The installer hides it with `"skillOverrides": {"rigs": "off"}` in `~/.claude/settings.json`. Run `./install.sh` again to put the setting back.

**The installer stops at "Missing: ...".**
Install the tools it names, or run `./install.sh --install-deps`. OpenRig needs Node 22 or 24.

## Daemon

**`rig daemon status` says it is not running.**
`/rig` starts it. By hand: `rig daemon start`. After a reboot, `rig start --last` also restores the rigs that were running.

**The daemon runs an older version than `rig --version`.**
This happens after an upgrade. `/rig` restarts the daemon, and the agents' tmux sessions survive. By hand: `rig daemon stop && rig daemon start --wait-for-kernel`.

**Port 7433 is in use.**
Another program uses the port. Find it with `lsof -nP -iTCP:7433 -sTCP:LISTEN`. Or run OpenRig on another port: `rig config set daemon.port 7444`, then `rig daemon start`.

**Something else is wrong with OpenRig.**
`rig doctor` checks the setup. `rig context get help` is OpenRig's own help guide.

## Agents in a team

**An agent stopped receiving messages after you scrolled its Herdr tile.**
Scrolling puts the agent's tmux pane into copy mode, and messages wait until it leaves that mode. Click the tile and press `q` or `Esc`. Or ask: `/rig builder@myapp is not getting messages`.

**An agent quit and its tile shows a plain shell.**
`/rig` gives it a fresh start: a new conversation in the same seat. Its queue work stays. If you resumed the old conversation in the tile yourself, ask `/rig adopt the session of builder@myapp`. It runs `rig reconcile-session`, so OpenRig tracks that session.

**An agent waits at an update, trust or "continue?" prompt.**
`/rig` answers routine prompts itself. It brings you prompts that grant new access, spend money or change the scope.

**A Codex agent shows "Hooks need review".**
A plugin hook is new or changed. `/rig` picks "Continue without trusting", so the agent works without that hook. To trust the hook, open the agent's tile, type `/hooks`, select the hook and press `t`. Codex keeps that choice on each machine.

**Agents fail with a login error.**
The sign-in expired. Run `claude` and use `/login`, or run `codex login`. Then ask `/rig` to restart the stopped agents.

**`/rig` inside an agent seat says it is for your own session.**
That is on purpose. `/rig` is for your own Claude Code session, not for the agents in a team. Agents use OpenRig's `openrig-skills`.

## Herdr

**`Cmd` shortcuts do nothing.**
Your terminal keeps `Cmd` keys for itself. Use a terminal that passes them on, such as Ghostty, or use the `ctrl+b` prefix keys (`ctrl+b`, then `?` lists them).

**Herdr reports a config error after an update.**
Run `herdr config check`. It names the line. To go back to the shipped settings: `./install.sh --replace-herdr-config` (your file is backed up first).

**You built Herdr yourself.**
Do not run `rig setup` without `--no-herdr`. `rig setup` runs Herdr's installer and can replace your build. Openrig-Mod's installer never replaces an existing Herdr.

## Undo

Each install log in `~/.config/openrig-mod/` lists every change with its undo step. `./uninstall.sh` takes back the changes. `./uninstall.sh --dry-run` shows the plan first.
