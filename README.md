# Openrig-Mod

Run teams of AI coding agents with [OpenRig](https://github.com/mvschwarz/openrig) by telling Claude Code what you want in plain words.

OpenRig runs agents (Claude Code, Codex) as a team in terminals: a lead, builders, reviewers, with a work queue between them. It has many commands. Openrig-Mod adds one Claude Code skill, `/rig`, that picks and runs those commands for you. It also sets up [Herdr](https://herdr.dev), a terminal workspace that shows which agent works, waits or is done.

```text
 ┌──────────── Herdr ─────────────────────────────────────────────┐
 │ rig tui (dashboard: rigs, seats,  │ claude                     │
 │ queue, what needs you)            │ > /rig set up a team to    │
 │                                   │   add tests to ~/src/app   │
 └───────────────────────────────────┴────────────────────────────┘
   Each team opens as its own Herdr workspace, one tile per agent.
```

## What you get

- **`/rig` skill for Claude Code.** Type `/rig`, with or without words. Each run first brings OpenRig up on all your machines: the daemon, the kernel team, the rigs you keep running, and a fresh start for stuck agents. Then it does what you asked: "what needs me", "set up a team to build X", "add a reviewer", "stop the docs rig". It writes the project, mission and slice files, starts the team, hands it the work, opens it in Herdr and reports back. It asks you only for real decisions.
- **Herdr settings.** A readable sidebar with agent state colors, toasts when an agent in another tab finishes, quick tab keys, a lazygit popup, and input fixes for Korean, Japanese and Chinese keyboards.
- **One installer and one uninstaller.** Both are safe to run again. They back up everything they change.

## Requirements

- macOS. Linux should work but is not tested yet.
- Node 22 or 24, npm, tmux, git, python3 and curl. `./install.sh --install-deps` installs missing tools with Homebrew or apt.
- [Claude Code](https://docs.anthropic.com/claude-code) with a signed-in account. Codex is optional.
- Go, only for the optional Herdr auto-title plugin.

## Install

```bash
git clone https://github.com/genius8267/Openrig-Mod.git
cd Openrig-Mod
./install.sh
```

The installer asks before it runs a third-party installer. Useful options:

| Option | Effect |
|---|---|
| `--dry-run` | Show the plan. Change nothing. |
| `--yes` | Answer yes to every question. |
| `--install-deps` | Install missing tools (Homebrew or apt). |
| `--no-herdr` | Skip Herdr. OpenRig still works in plain tmux. |
| `--replace-herdr-config` | Use the shipped Herdr settings in place of yours (yours is backed up). |
| `--codex-skill` | Also install `/rig` for Codex (`~/.agents/skills`). |
| `--no-kernel` | Start the daemon without OpenRig's kernel team (for extra machines). |

`./install.sh --help` lists all options.

### What the installer changes

| What | Where | Notes |
|---|---|---|
| OpenRig CLI (`@openrig/cli` 0.6.10) | global npm, or `~/.npm-global` when global npm is not writable | Adds two marked PATH lines to your shell startup file in the second case. An existing different version stays unless you pass `--upgrade-openrig`. |
| Herdr | `~/.local/bin/herdr` | Only when Herdr is missing. Uses Herdr's official installer. |
| Herdr settings | `~/.config/herdr/config.toml` | Only when you have no config. |
| Herdr auto-title plugin | Herdr plugin folder | Only when Go is installed. Pinned to one commit. |
| `/rig` skill | `~/.claude/skills/rig` | |
| Claude Code setting | `~/.claude/settings.json` | Adds `"skillOverrides": {"rigs": "off"}`, which hides OpenRig's built-in `rigs` skill so you have one entry point. OpenRig restores `rigs` on each upgrade, so a setting is used in place of a delete. |
| Machine notes | `~/.config/openrig-mod/machine-notes.md` | Your local team preferences and the facts `/rig` learns about your machines. Never published. |
| OpenRig settings | `~/.openrig` | Only keys still at their defaults: context warnings at 80 and 90 percent, your time zone, a short host name. |
| OpenRig daemon | local process | Started on port 7433. |

Each run writes a log with the undo step for every change to `~/.config/openrig-mod/install-<time>.log`. Backups go to `~/.config/openrig-mod/backups/<time>/`.

## First use

1. Open a new terminal, so PATH changes apply. Start Herdr: `herdr`
2. Sign in to your agents if you have not: run `claude` once (and `codex login` if you use Codex).
3. Split the Herdr window: press `ctrl+b`, then `v`. (Or right-click a pane.)
4. In the left pane run `rig tui`. In the right pane run `claude`.
5. In Claude Code, type `/rig what can you do?`

Then describe what you want. Examples:

```text
/rig
/rig set up a small team to add tests to ~/src/myapp
/rig add a Codex reviewer to the myapp rig
/rig what is the myapp team doing?
/rig stop the myapp rig, I am done for today
/rig bring my rigs back after the reboot
/rig add my other machine "studio"
```

`/rig` with no words brings OpenRig up on every machine, fixes what it safely can, opens the OpenRig view, and lists what needs you, with a recommended answer for each. Reply `go` to accept all recommendations. On a healthy fleet of four Macs, the bring-up takes about 4 seconds.

## How `/rig` behaves

- **It acts on its own** for anything that you asked for or that can be undone: starting and stopping teams you named, adding seats, messages, queue work, reminders, snapshots, restores.
- **It asks first** before anything that cannot be undone or leaves your machines: `rig destroy`, deletes, git push, PR merge, deploys, payments, posts in your name.
- **Teams build, `/rig` orchestrates.** It writes specs and work items. It hands code changes to a team through the OpenRig queue.
- **It uses OpenRig's own screens.** `rig tui` is the dashboard. `/rig` checks that it runs and points it at new work. Teams open with `rig terminal open <rig> --window`, one Herdr tile per agent.
- **It heals stuck agents.** An agent that quit or lost its session gets a fresh start: a new conversation in the same seat. Its queue work stays. A Codex "Hooks need review" prompt gets "Continue without trusting". To trust a hook, type `/hooks` in that agent's tile.
- **It keeps receipts.** Each fleet change gets a dated note with its undo step in `<OpenRig workspace>/artifacts/ops-receipts/`.
- **It learns your setup** in the machine notes file: your team preferences, other machines, rigs to keep running, rigs to leave alone, quirks.
- **Agents inside a team do not use it.** `/rig` is for your own Claude Code session. Seats keep OpenRig's `openrig-skills`.

## Herdr keys

The `ctrl+b` prefix keys are Herdr's defaults. Press `ctrl+b`, then `?` to see all of them.

| Key | Action |
|---|---|
| `ctrl+b` `v` / `ctrl+b` `-` | Split right / split down |
| `Cmd+Shift+C` / `Cmd+Shift+X` | New tab / close tab |
| `Cmd+R` | Rename tab |
| `Shift+Left` / `Shift+Right` | Previous / next tab |
| `Shift+Up` / `Shift+Down` | Previous / next workspace |
| `Alt+Up` / `Alt+Down` | Next / previous pane |
| `Cmd+K` | Go to a workspace, tab or pane |
| `Cmd+Shift+G` | Lazygit for the focused pane (needs lazygit) |

`Cmd` keys work only in terminals that pass `Cmd` to programs, such as [Ghostty](https://ghostty.org). The prefix keys work in every terminal. Change any key in `~/.config/herdr/config.toml`, then run `herdr config check`.

Sidebar colors: red means the agent waits for you, yellow means it works, blue means it finished and you did not look yet, gray means idle.

## More than one machine

Run the installer on each machine and connect them with Tailscale. Then let each machine list the others. A `/rig` on any machine keeps all of them running. See [docs/multi-machine.md](docs/multi-machine.md).

## Update

```bash
cd Openrig-Mod && git pull && ./install.sh
```

The installer replaces the skill (the old copy is backed up) and keeps your Herdr settings and machine notes. To move to the OpenRig version this repository was tested with, add `--upgrade-openrig`, then restart the daemon: `rig daemon stop && rig daemon start`. A `/rig` also restarts a daemon that runs an older version than the CLI.

## Uninstall

```bash
./uninstall.sh          # skill, setting, PATH lines, Herdr settings (only if unchanged)
./uninstall.sh --all    # also stops the daemon and removes the OpenRig CLI and the auto-title plugin
```

The uninstaller moves files into `~/.config/openrig-mod/uninstalled/<time>/` in place of a delete. Your rigs and history in `~/.openrig` and your machine notes stay. Herdr itself stays.

## Problems

See [docs/troubleshooting.md](docs/troubleshooting.md). OpenRig's own help guide: `rig context get help`.

## Safety

- OpenRig teams are AI agents that run commands on your machine. Start teams only in folders you are ready to let agents change, and read OpenRig's documentation about permission policies.
- `/rig` never reads credential files or `.env` files and never prints resume tokens.
- The installer downloads only from npm (`@openrig/cli`), herdr.dev (Herdr) and GitHub (the auto-title plugin at a pinned commit).
- This repository holds no secrets or personal data. `python3 tools/check-publish-safety.py` checks that before each push. Put your own private words in `.git/info/private-patterns` to check for them too.

## Credits and licenses

- [OpenRig](https://github.com/mvschwarz/openrig), Apache-2.0. Installed from npm, not included here.
- [Herdr](https://herdr.dev). Installed with its own installer, not included here. See its repository for its license.
- [herdr-auto-title](https://github.com/kryptamine/herdr-auto-title), MIT. Installed by Herdr's plugin manager, not included here.
- Openrig-Mod (this repository): MIT, see [LICENSE](LICENSE).

Openrig-Mod is a community add-on. It is not part of OpenRig or Herdr.
