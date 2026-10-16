# Routing table: owner words to rig commands

Find the row that matches the request. Run its read commands first, then the act commands. "Load" names the shipped OpenRig guide to read with `rig context get <ref>` when you need more than the row gives. Exact flags: `rig <verb> --help` (help wins over this file).

Tiers:
- R: read. Run.
- A: act. Run, then report.
- N: runs when the owner's words name it. If it is your own idea and seats hold open work, ask once with your recommendation.
- X: ask once first, always (cannot be undone, or reaches outside the machines). The list is at the end.

Other machines: add `--host <id>` where the verb has it (HTTP host entries: up, down, launch, transcript, broadcast, queue create/handoff); otherwise run on that machine with `scripts/rig-on <host> ...`. A selected remote host silently redirects ps, whoami, send, capture, transcript, broadcast, launch, up and down: use the local prefix from section 0 step 1 for this machine, and `--host` for the other one.

Identity for writes: this session is not a seat, so every command that writes (queue update, block, resolve, handoff; chatroom send, topic, clear; watchdog register, stop; seat set-*; compact; workflow instantiate, abort; scope approve) needs `OPENRIG_SESSION_NAME` set in front of it, or it fails with `actor_required`. Use `OPENRIG_SESSION_NAME=rig-skill` for your own actions and `OPENRIG_SESSION_NAME=human@kernel` only to record the owner's own decision or words. `rig queue create` takes `--source rig-skill` instead. `scripts/rig-on` forwards the variable to the other machine. tmux targets for a seat's pane are `'=<pod-member>@<rig>:'` (the trailing colon is required).

## 0. Bring-up and show (every `/rig`; replaces the shipped `rigs` skill)
`scripts/rig-up` runs steps 1 to 6 on this machine and on every reachable machine. `scripts/rig-up --show` adds steps 7 to 10. Run the steps by hand only for a `gaps` entry or when the script cannot run. Run steps 1 to 6 first and steps 7 to 10 last, after the request. Each step reads first and acts only on a gap, so a second run changes nothing. A step that fails goes in the report. Continue with the next step that does not depend on it.
Fleet: each `/rig` keeps the kernel running on every machine in `rig host list` that Tailscale reports online. A machine whose daemon gives no answer gets `scripts/rig-on <id> start --last`.

1. Host: `rig config get host.selected`. If it names another machine, the owner's plain `rig` commands go there (ps, whoami, send, capture, transcript, broadcast, launch, up, down). Put `OPENRIG_HOST_SELECTED=local` (the local prefix) in front of every rig command for this machine. Queue writes do not follow the selection. Do not change it. If the machine notes do not record it yet, report it once and add it to the notes. `rig host select local` changes it, only on the owner's word.
2. Install: if `rig --version` fails, OpenRig needs macOS or Linux, Node 22 or 24, tmux, and Claude Code or Codex signed in. Install with `npm install -g @openrig/cli` (if the global npm folder is not writable, `npm install -g --prefix ~/.npm-global @openrig/cli` and put `~/.npm-global/bin` on PATH), then `rig preflight` and `rig doctor` (A). The Openrig-Mod installer does all of this. Never `rig setup` without `--no-herdr`.
3. Daemon: `rig daemon status`.
   - Down: `NODE_DISABLE_COMPILE_CACHE=1 rig start --last --json` (A). It starts the daemon, checks the kernel and restores the rigs that were last running. Add `--no-kernel` to `rig daemon start` instead on machines the machine notes mark as daemon-only.
   - Up: compare `semver` and `commit` from `curl -s -m 3 http://127.0.0.1:<port>/healthz` (port from `rig daemon status`) with `rig --version`. If they differ, the daemon still runs an older CLI. Run `rig daemon stop`, then `NODE_DISABLE_COMPILE_CACHE=1 rig daemon start --wait-for-kernel` (A). The tmux sessions survive this. If `stop` exits non-zero, read `rig daemon status` and `rig daemon logs`, and do not repeat it. If `/healthz` gives no answer, skip the check and say so.
4. Kernel: read the `Kernel:` line of `rig status` and `rig ps --nodes --rig kernel --json`.
   - `auth_blocked`: no runtime is signed in. Give the owner the one sign-in command (`claude auth login` or `codex login`).
   - `skipped` after a restart means the kernel exists. Read its seats.
   - A seat that is not `running` and `ready`: heal it with section 2. A `detached` seat (its tmux session is gone): `rig launch kernel <pod.member>` (A).
   - Every kernel seat failed and none is live: `rig up kernel --existing` (A). For each seat whose resume failed: `rig up kernel --existing --fresh <logicalIds> --yes` (A). Report that each one started a new conversation.
   - Do not recreate the kernel or change its topology to open a view.
5. Rigs to keep running: for each rig in the machine notes "Keep running" line that is not running, `rig up <rig> --existing` (A). `partially_restored` or exit 1 names a seat that lacks part of its guidance or failed: heal it with section 2 or report it. Leave every other stopped rig stopped. On a bare `/rig`, name them in one report line.
6. Seats: heal routine attention in the running rigs with section 2.
7. Dashboard: the kernel's `operator-human` terminal runs the TUI. Read it with `env -u TMUX tmux capture-pane -p -t '=operator-human@kernel:' | head -3`. The first line starts with `cmd ▸` while the TUI runs. If the pane shows a shell, start the TUI: `env -u TMUX tmux send-keys -t '=operator-human@kernel:' -l 'rig tui'`, then `env -u TMUX tmux send-keys -t '=operator-human@kernel:' Enter` (A). If the seat's `tmuxAttachCommand` names `-L <name>` or `-S <path>`, add the same option to each tmux command.
8. Point the dashboard at the work: if this run registered or advanced work, type `project <id>`, then `mission <name>`, into the dashboard with the same two send-keys commands (A). Type only when the first line reads `cmd ▸ ▊  Tab complete`, which means the command bar is empty. Capture again to confirm, and say in the report that you changed the dashboard's view. Other dashboard commands: `projects`, `source`, `attention`, `: topology`.
9. Open the view: `rig terminal open saved:kernel --window --json` (A).
   - Inside a Herdr pane (`HERDR_ENV=1`, with `HERDR_PANE_ID` and `HERDR_SOCKET_PATH` set), put `env -u SSH_CONNECTION -u SSH_CLIENT -u SSH_TTY` in front. The CLI refuses SSH before it checks for Herdr. Its current-Herdr route opens no desktop window and needs the pane's Herdr socket to match the daemon's.
   - In Herdr it focuses the live `openrig kernel` space with the same plan (`reusedWorkspace`), or creates one. The plan depends on the width: below 120 columns or from 120 columns. A width change gives one more space.
   - Never use `--provider herdr` for this view. It creates a new space on every call and reuses none.
   - Outside Herdr it opens a new terminal window or tab. Before that, say that clicking Allow on the one-time macOS Automation prompt is fine.
   - Read `opened`, `reusedWorkspace`, `absent`, `degraded` and `notes`. Report absent or degraded roles as they are. Report extra `openrig kernel` spaces with `herdr workspace close <id>`, and close nothing.
   - Not opened (SSH outside Herdr, a Herdr endpoint mismatch, no display, a denied prompt): report the reason once, and give the `run:` command it printed, exactly. `rig tui --shared` is the dashboard-only fallback (Ctrl-b, then d, detaches). Do not retry in another app.
   - The result does not prove that the owner sees the view. The note "Herdr shows the openrig kernel space in the person's current session" is the best evidence. Report it as OpenRig's claim.
10. A team this run started or changed on this machine: run step 9 with `<team>` in place of `saved:kernel` (A). It opens the team as its own Herdr space, one tile per seat. The same plan reuses its space. Changed membership creates a new one.

- The kernel's operator can also start teams for the owner. This skill does that work itself, so the owner never has to switch panes.
- Load: `help` when anything in install or start fails, and `reference/getting-started.md#incomplete-setup-and-restart` for restart symptoms.

## 1. Status: "what's running", "how is X", "what needs me"
- Read, in one batch: `rig ps --json` (rigs, ATTN counts), `rig ps --nodes -A --json` (seats: `lifecycleState`, `startupStatus`, `agentActivity.state`, work counts), `rig view show held --json`, `rig view show escalations --json`, `rig queue list -A --json --limit 1000`.
- Needs attention: seats with `lifecycleState` or `startupStatus` `attention_required`/`failed`, or `agentActivity.state` `needs_input`; held rows whose `blocked_on` is `human@...`; open queue rows (pending, in-progress, blocked) whose `destinationSession` is `human@...` or `...@external` (read each with `rig queue show <id> --json` for its summary and questions); escalation rows. `lifecycleState` is the liveness field; `sessionStatus` is legacy. Activity `unknown` with no reason is an idle seat without a hook, not a problem.
- Heal what is routine first (section 2), then report what is left as owner decisions, each with a recommended answer.
- Another machine, only when named or when the work lives there: `rig ps --host <id> --nodes -A --json`, and `scripts/rig-on <id> queue list -A --json` / `view show held --json` for its decisions.
- What a seat is doing: `rig capture <seat> --lines 60` (a glance, not a feed), `rig transcript <seat> --tail 100`, `rig ask <rig> "<question>"` (searches history, wakes nobody).
- Load: `skills/openrig-user` (syntax), `onboarding-width` (what is possible).

## 2. Heal stuck seats (do this without being asked)
- The owner keeps no old conversations. A stuck seat with no live question gets a fresh occupant (`rig seat launch <seat> --fresh --stop`), not a resume attempt. Its queue rows stay with the seat. `scripts/rig-up` does this, and the rules below cover what it reports as `gaps`.
- Codex "Hooks need review" prompt: answer `3` ("Continue without trusting"), then `rig seat continue <seat>`. Trusting changed hooks lets them run outside the sandbox. That is the owner's call.
- Read the record before the pane: `rig seat status <seat>`, the node row (`lifecycleState`, `startupStatus`, `heldReason`, `latestError`, `agentActivity.reason`), then `rig capture <seat> --lines 40`.
- Routine prompt on screen (Codex or Claude update offer, trust this folder, continue, the default the team launched with): `rig send <seat> "<key>" --dangerously-interact --reason "<why>"` (A). ESC is sent as `$'\e'`, Enter as a carriage return. A prompt that grants new access, spends money or changes scope goes to the owner.
- Startup context not delivered after a prompt: `rig seat continue <seat>` (A).
- Messages stack up unsent (the prompt shows `[Pasted text #n]`, `--verify` says rendered-unconfirmed, compaction stops at `preparation_incomplete`): check `env -u TMUX tmux display-message -p -t '=<seat>:' '#{pane_in_mode}'`. `1` means the pane is in tmux copy mode, usually because someone scrolled in an attached Herdr tile; leave it with `env -u TMUX tmux send-keys -t '=<seat>:' -X cancel`, then submit the stacked input once with `env -u TMUX tmux send-keys -t '=<seat>:' Enter` (A).
- The agent quit and the pane shows a shell (`rig launch` then refuses: "already running"): `rig seat launch <seat> --fresh --stop --reason "<why>"` (A). If the owner resumed the conversation in the pane by hand, adopt that session instead: `rig reconcile-session <seat> --rig <rigId> --node <pod.member>` (A).
- A blank or dead occupant with no open work: `rig seat launch <seat> --fresh --stop --reason "<why>"` (A). With open work rows, hand them on first (`rig queue handoff`) or ask.
- A stale flag with live evidence against it: `rig seat clear-attention <seat> --reason "<evidence>"` (A). Some classes (restore outcome) cannot be cleared by a reason; report those instead of repeating fixes.
- Seats failing on login or auth errors (for example `401`, `auth_unavailable`, a sign-in prompt): the runtime's login on this machine expired. That is the owner's sign-in: give them the one command (`claude auth login`, `codex login`, or the gateway's own login if the machine notes name one).
- Try each fix once, verify, and record it in the receipt.

## 3. Owner decisions
- A row asking the owner (destination `human@...`/`...@external`, or held on `human@kernel`): show the question in plain words with your recommended answer. With the owner's answer (or "go" for your recommendation), reply the way the row's body asks (for example "reply in this thread or in the lead terminal" means `rig send <lead> "<item>: owner picks <answer>"`), and let the asking seat close its own row. For a row blocked on `human@kernel`: `OPENRIG_SESSION_NAME=human@kernel rig queue resolve <id> --decision "<text>"` (A).
- Load: `skills/core/human-in-the-loop`, `skills/core/messaging-the-human`.

## 4. Start or restore teams: "start my rig", "bring everything back"
- Read: `rig ps --json`, `rig restore-check --json`, `rig ps --nodes --rig <r> --json`.
- Restore a stopped rig: `rig up <rig> --existing` (A). Whole machine: `rig start --last` (A). Never `rig up <spec>` for a rig that exists; that starts a new team.
- One seat: `rig launch <rigId> <pod.member>` (A) for seats in the rig's spec. Seats added with `rig grow` are not in the spec; relaunch them with `rig seat launch <seat> --fresh --reason`.
- Load: `skills/core/rig-lifecycle`.

## 5. New team or new work from an intent: "set up a team for X", "I want Y built"
- Follow `references/intent-pipeline.md` end to end (A throughout).
- If the machine notes name an intake or factory team for a repository, route changes for that repository there instead of starting a new team.
- Load: `skills/core/openrig-software-factory` (starter, workshop, factory), `skills/core/openrig-architect` (custom specs).

## 6. Change a running team: "add a reviewer", "a second QA", "drop the design seat"
- Read: `rig ps --nodes --rig <r> --json`, the rig's spec (`rig spec show <rigId>` or its file in the spec library).
- Add seats: `rig grow <rig> <member...> --pod <pod>|--new-pod <pod> --runtime claude-code|codex --cwd <abs>` (A). From a fragment: `rig add`, `rig expand` (A). Give each new seat its role with a queue row or message.
- Remove: `rig remove <rig> <pod.member> --fallback <live-seat>`, `rig shrink <rig> <pod> --fallback <seat>` (N). Work rows move to the fallback.
- Keep the spec true: mirror the change in the rig's spec file (and commit it if the spec library is a git repo), so a later `rig up` matches.
- Load: `skills/core/topology-mutation-and-seat-management`.

## 7. Stop: "stop X", "pause", "stand down", "shut it all down"
- Short hold: `rig send <seat> "hold"` (A); seats answer ACK PAUSED. Wind down: send "stand down" (A).
- Stop a rig: `rig down <rig> --snapshot` (N). Not for tidying up or saving money: idle seats cost nothing.
- Stop everything: each rig, kernel last, then `rig daemon stop` (N).
- Retire: `rig archive <rig>` (N, reversible with `rig unarchive`).

## 8. Talk to a seat or the team
- Inform: `rig send <seat> "<text>" --verify` (A). Exit 1 with "rendered-unconfirmed" means delivered but not confirmed on screen; confirm by effect or `rig capture`, and do not resend blind. Several: `--to a,b`, `--pod`, `--rig`; all of a rig: `rig broadcast "<text>" --rig <r>` (A).
- Work someone must own: a queue row, not a message (section 9).
- Cross-machine: `<pod-member>@<rig>@<host-id>` for send and capture.
- Shared room: `OPENRIG_SESSION_NAME=rig-skill rig chatroom send <rig> "<text>"`, `rig chatroom history <rig>`; `chatroom wait` blocks until someone speaks, so nobody polls.

## 9. Give and follow work
- Create: write the brief to a file, then `rig queue create --source rig-skill --destination <seat> --body-file <file> --summary "<subject>" [--mission <m> --slice <s>] [--host <id>]`, then `rig send <seat> "Queue handoff: <id>, check your queue"` (A).
- Follow: `rig queue list --destination <seat> -a --json`, `rig queue show <id> --full`, `rig queue transitions <id>`; follow `handedOffFrom` to the current owner. Report what the team produced (branch, commit, PR text), not that you sent it.
- Rerouting: `OPENRIG_SESSION_NAME=rig-skill rig queue handoff <id> --to <seat> --summary "<subject>"` (A). Notes: `OPENRIG_SESSION_NAME=rig-skill rig queue update <id> --note "<text>"`. Close a row you own or created by mistake: `... rig queue update <id> --state done --closure-reason canceled --note "<why>"`.
- Load: `skills/queue-handoff`.

## 10. Keep work moving: reminders, wakes, workflows
- Reminder (from the folder that holds the spec YAML): `OPENRIG_SESSION_NAME=rig-skill rig watchdog register --policy periodic-reminder --target-session <seat> --interval-seconds 1800 --registered-by rig-skill --spec <yaml>` (A). Stop it when the thread ends: `OPENRIG_SESSION_NAME=rig-skill rig watchdog stop <id> --reason "<why>"` (A).
- Context guard: `--policy context-usage-threshold --target-session <seat>` (A).
- Lifecycle run for a mission: `rig workflow compile <missionPath>` (R), `OPENRIG_SESSION_NAME=rig-skill rig workflow instantiate-lifecycle <missionPath> --rig <team> --root-objective "<intent>" --created-by rig-skill --operation-key <stable-unique-key>` (A). Follow: `rig workflow status|show|trace` (R). Redrive a failed run: `rig workflow resume` (A). `rig workflow abort <id> --reason "<why>" --actor-session rig-skill` (N).
- Load: `skills/core/watchdog`.

## 11. Continuity: compaction, handover, snapshots
- Read: `rig compact-plan --json`, `rig seat status <seat>`, `rig snapshot list <rigId>`.
- Snapshot: `rig snapshot <rigId>` (A). Restore a stopped rig from a snapshot: `rig restore <snap> --rig <rigId>` (A); read the attempt with `rig restore status <attempt> --rig <rigId>`.
- A seat near its context limit: `rig handover <seat> --reason "<why>" --dry-run` (R), then perform it (A) after `rig context recap-write`. Compact a Claude seat: `OPENRIG_SESSION_NAME=rig-skill rig compact <seat>` (N, lossy; prefer handover). It first asks the seat to write a restore map; `preparation_incomplete` usually means stacked unsent input (section 2). Follow it with `rig compact <seat> --state --json`.
- Load: `skills/seat-continuity-and-handover`, `skills/claude-compaction-restore`.

## 12. Other machines
- Read: `rig host list --json`, `rig host doctor <id>`, `rig ps --host <id> --json` (0.3 s each). `rig ps --all-hosts --json` waits for offline machines (10.7 s here).
- One fleet: every machine lists every other machine with the same ids, as `transport: http` and `url: http://<MagicDNS name>:7433`, with no token. The daemon listens on Tailscale only, never on a public address. `~/.openrig/hosts.yaml` is the registry. Back it up, then edit it, or use `rig host add --id <name> --transport http --url http://<MagicDNS name>:7433` and `rig host doctor <name>`. `rig host pair` needs a bearer token on the target, so it does not apply to tokenless daemons. Add each new machine to every machine's registry with `scripts/rig-on`, and record it in the machine notes.- Act on a machine without `--host` support: `scripts/rig-on <host> <args>`.
- A new team on another machine: `scripts/rig-on <host> up <team or spec path> --cwd <path on that machine> --plan`, then without `--plan`. `rig up --host` accepts only an existing rig name or a spec path that exists on that machine.
- Move one file: `rig file copy <src> <host>:<abs>` (SSH entries only; `--dry-run` first because it overwrites).
- Load: `skills/core/cross-host-rig-commands`.

## 13. See it (OpenRig's own screens)
- The OpenRig view (dashboard TUI, operator and advisor): section 0 steps 7 to 9. Below 120 columns the operator fills the first page. From 120 columns the dashboard and operator share it. The advisor has its own tab.
- Another machine's TUI: the dashboard command `host <id>`, or `OPENRIG_URL=http://<MagicDNS name>:7433 rig tui` (the URL is in `rig host list --json`).
- A team's terminals: section 0 step 10 opens the rig as its own Herdr workspace, one tile per seat (up to 16 per tab). Closing a tile leaves the seat running. Pod or work views: `pod:<rig>/<pod>`, `mission:<id>`, `slice:<id>`. Saved views and provider state: `rig terminal views --json`, `rig terminal status --json`.
- Manual attach (the owner asks, or no window can open): `rig ps --nodes --rig kernel --json --fields logicalId,canonicalSessionName,tmuxAttachCommand`, then `env -u TMUX <tmuxAttachCommand>` of the `operator.agent` row.
- Seats on another machine cannot be tiled from here; give the owner `ssh -t <machine> "env -u TMUX tmux attach-session -t '=<seat>'"` or open the view on that machine.
- Herdr tiles from `rig terminal open` are live tmux attaches: scrolling in one puts the seat's pane into copy mode and stops deliveries until it is left (q or Esc). Section 2 has the fix.
- Before the owner types into a seat: `rig seat set-typing-guard <seat> --enabled true --reason "owner typing"`, and off afterwards.
- Load: `skills/core/openrig-herdr`.

## 14. Health, upgrades, recovery
- Order: `rig preflight`, `rig doctor`, `rig daemon status`, `rig health --instance --json` (or `--rig <r>`, `--seat <seat>`; plain `rig health` needs a seat identity), then panes. Empty output is not health.
- Daemon down: `rig daemon logs`, `rig crash-cart --json` (R), then `rig daemon start` (A).
- Upgrade OpenRig (N): follow `skills/core/openrig-upgrade` (snapshot, DB backup, staged install, daemon stop and start, verify seats). Never `rig setup` without `--no-herdr`.
- Load: `help` (troubleshooting guide for the installed version).

## 15. Context, skills, permissions, Slack
- Context: `rig context list|get|profile|work-install` (R/A).
- Seat permissions: `rig seat set-permissions <seat> --mode floor|full_bypass|inherit --reason` (A, applies at next launch). Owner default is unrestricted.
- Slack: `rig slack status|verify` (R/A). Changing channels or the gateway human (N).

## X: ask once first, always
`rig destroy`, `release --delete`, `down --delete`, `specs remove`, `context rm`, `chatroom clear`, `agent-image delete` or `prune --force`, `auth switch`, `env down --volumes`, `config reset` with no key, `file copy` over an existing file, `rig setup`; anything outward: git push, PR merge (factory merge only on the owner's explicit word), deploy, publishing, payments, Slack posts in the owner's name.
