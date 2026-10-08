# Machine notes for the rig skill

The `/rig` skill reads this file at the start of a session and adds one line when it learns a durable fact. It lives at `~/.config/openrig-mod/machine-notes.md` on each machine and is never published. Do not put secrets, tokens or passwords here.

## Team preferences

Edit these to taste; the skill applies them when it creates or changes teams.

- Pairing: pair the model families when both Claude Code and Codex are signed in (one writes, the other checks).
- Models and effort: let each runtime use its own configured default.
- Permissions: OpenRig's default permission policy for new teams.
- Ask before: anything that cannot be undone or leaves this machine (the skill's built-in ask list).

## Machines

One line per machine this one can reach, filled in as hosts are added (`rig host list --json`).

- (this machine) `<host.name>`: daemon with kernel.

## Rigs

- Leave alone (another session or person owns them): none yet.
- Intake or factory teams by repository: none yet. Example line: `~/src/app -> lead@app-factory (send changes there)`.

## Quirks learned

- (none yet)
