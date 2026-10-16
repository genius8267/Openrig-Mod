# Intent pipeline: from the owner's words to a working team

The owner describes an outcome. This session writes everything OpenRig needs (project, mission, slices, team spec, queue work, wakes) and starts the work, then reports. It does not write the product code: that is the team's job. Proceed through every step without stopping; the only question allowed is the one marked ASK in step 0.

## 0. Understand the intent

Write one sentence: the outcome, for whom, and what counts as done. Fill the gaps from what is already known (the repo the owner is in, the fleet, existing projects, earlier conversation). Ask one question only when the outcome itself or the target repository is unknown (ASK). Note what is out of scope; when unsure, keep the first slice small.

## 1. Pick the route

| The intent is | Route |
|---|---|
| A change to a repository the machine notes assign to an intake or factory team | Hand it to that team's lead as a queue row (or its own intake command, if the notes name one). Skip to step 9. |
| A question, a status check or a fleet operation | `references/routes.md`. Register nothing. |
| A document, research or a design that this session writes itself (no product code) | Steps 2 and 3, then do the work. Record each result on the slice with `OPENRIG_SESSION_NAME=rig-skill rig scope --workspace <root> slice progress <NN-slug> --mission <mission> --add "<result and path>" --status done`. Skip steps 4 to 8. |
| Ongoing work, several steps, another repository, or a new product area | Steps 2 to 10. |

## 2. Project

Work tree root `<W>`: `rig config get workspace.root`. If it is unset or the folder has no `workspace.yaml`, run `rig config init-workspace` once and read the root again.

1. Look for a fitting project: `<W>/workspace.yaml` (`projects:` ids and roots) and each project's `SPEC.md` intent. Reuse one when the repository or area matches.
2. Otherwise create it:
   - Folder `<W>/projects/<id>/` with `missions/`.
   - `SPEC.md`: frontmatter `intent: "<one sentence>"` (quote values that contain `: `), then `# Project: <Title>`, `## Intent`, `## Repository` (absolute path and branch), `## Done means`, `## Out of scope`.
   - `project.yaml`: copy `references/project-template.yaml` from this skill, set `metadata: { id: <id> }`, and point `workflow.roles.*.preferred_targets` at the seats of the team chosen in step 4 (lead, driver, qa, reviewer).
   - Back up `workspace.yaml` next to it as `workspace.yaml.bak-<timestamp>`, then append `  - id: <id>` and `    root: projects/<id>`.
   - Check: `rig workspace validate <project folder>` and `rig workspace doctor` (the TUI PROJECTS list reads this file live).

## 3. Mission and slices

Root for scope commands: `<W>` for the root project (the one whose root is `.` in `workspace.yaml`), `<W>/projects/<id>` for the others. Inspect each returned path.

1. Mission: `rig scope --workspace <root> mission create <slug> --title "<Title>" --intent "<mission intent>" --json`. Confirm `mission.yaml` has `metadata: { name: <slug> }` (workflow compile needs it; add it if missing).
2. Slices: split the mission into 1 to 5 slices, each small enough to build and prove in one pass, ordered by dependency. For each:
   `rig scope --workspace <root> slice create <mission> <slug> --intent "<slice intent>" [--template bug-fix] [--depends-on <dot-id>] --json`
3. Write each slice's `SPEC.md` body under the generated frontmatter:
   - `## Intent`
   - `## Mini-requirements`: numbered, each one testable.
   - `## Proof contract`: checkboxes, each naming the exact command or observable result that proves it.
   - `## Out of scope`, `## Source material` (paths the builder should read).
   For the conventions, read `rig context get skills/mission-slice-sop`.
4. Plan lock on the owner's delegation, for missions in the root project only: `cd <W> && OPENRIG_SESSION_NAME=rig-skill rig scope slice approve <mission>/slices/<NN-slug> --scope spec --on-behalf-of human@kernel --json`. The daemon resolves approvals and `rig proof show` only under the root project's `missions/`; for other projects skip the stamp (the lead's plan step covers it) and read proof from the slice's `proof/` folder. Leave the delivery sign-off (`--scope delivery`) to the owner.
5. Check: `rig scope --workspace <root> audit --mission <mission> --json` (advisory) and fix real gaps.

## 4. Team

Choose the smallest team that fits, in this order:

1. An existing team with the right repo and spare capacity (see `rig ps` and the machine notes). Reuse keeps context; route the work to its lead.
2. A built-in or published team (`rig specs ls --kind rig --json`, `rig specs preview <name> --kind rig --json`):
   - `starter`: builder (Claude) and reviewer (Codex), one bounded change.
   - `workshop`: lead, builder, QA, reviewer, ongoing work in one repo. Install from the registry pin: read the commit from `https://raw.githubusercontent.com/mvschwarz/openrig-registry/main/registry/workshop.yaml` (fetch it fresh), then `rig up https://github.com/mvschwarz/openrig-world/tree/<commit>/rigs/workshop --target ~/rigs/workshop --cwd <repo>`.
   - `factory`: seven seats, sustained product work.
   - Shelf: `code-review`, `research`, `pm`.
3. A custom team when the roles differ: write `~/.openrig/specs/<name>/rig.yaml` following a shipped spec (`rig specs preview starter --kind rig --json` gives its `sourcePath`): culture file, pods, members with runtime and model, edges, the permission policy from the machine notes, absolute `cwd`. Run `rig spec validate <path>` and `rig spec preflight <path>`, add it with `rig specs add <folder>` (commit it too if that folder is a git repo). Read `rig context get skills/core/openrig-architect` for the format.

Team preferences (models, effort, permissions, pairing) come from the machine notes. Default when none are set: pair the model families when both are signed in (Claude writes, Codex checks, or the reverse), let each runtime use its configured default model, and keep OpenRig's default permission policy.

## 5. Placement

- Default: this machine.
- Another machine when the machine notes say so, when this machine's load is high (`uptime`), or when the owner names one.
- A machine without the repository: deliver it first (clone it there, or `git bundle create` here, copy it with `scp`, and `git clone <bundle>` there).
- Remote launch: `scripts/rig-on <host> up <team or spec path> --cwd <path on that machine> --plan`, then without `--plan`. (`rig up --host` accepts only an existing rig name or a spec path on that machine.)

## 6. Launch

1. Plan: `rig up <team | spec path | link> --cwd <abs repo> --plan --json`. Read the seat count, runtimes, folder and any non-interruptive or broad-access notes.
2. Do not ask. Mention the seat count, providers and machine in the report. If the chosen machine lacks the repository, deliver it first (step 5).
3. Launch: the same command with `--yes --json` instead of `--plan`.
4. Readiness: read `rig ps --nodes --rig <team> --json` every 20 s for up to 3 minutes. Only `startupStatus: ready` is ready; `pending` is still starting; `attention_required` or `failed` go to routes section 2. Report a partial start honestly with each waiting seat's reason.
5. Relay untracked-file notes from `rig up` (OpenRig writes managed `CLAUDE.md`/`AGENTS.md` blocks and skills into the repo).

## 7. Hand the work to the lead

1. Write the brief to `<W>/artifacts/briefs/<yyyymmdd>-<slug>.md`: the owner's intent in their words, project and mission paths, the first slice, repository and branch, done means, out of scope, and the owner's standing rules (no push, merge, deploy or publish without the owner; report results back as queue rows to `rig-skill`).
2. When the project's lifecycle roles point at this team: `rig workflow compile <missionPath> --json`, then `OPENRIG_SESSION_NAME=rig-skill rig workflow instantiate-lifecycle <missionPath> --rig <team> --root-objective "<intent>" --created-by rig-skill --operation-key <project>-<mission>-<yyyymmdd> --json`. The entry row goes to the lead role.
3. Otherwise: `rig queue create --source rig-skill --destination <lead> --body-file <brief> --summary "<subject>" --mission <mission> --slice <first-slice> --json`, then `rig send <lead> "Queue handoff: <qitem>, check your queue"`.

## 8. Keep it moving

- Workflow runs arm their own keepalive watchdog.
- Plain queue work: `OPENRIG_SESSION_NAME=rig-skill rig watchdog register --policy periodic-reminder --target-session <lead> --interval-seconds 1800 --registered-by rig-skill --spec <yaml>` with a message such as "Check your queue. Continue unfinished work or hand it to its next owner." Note the job id in the brief; stop it when the mission closes.

## 9. Show it

- Run `scripts/rig-up --show --project <id> --mission <name> --open <team>` (routes section 0 steps 7 to 10): it points the dashboard at the project and mission, opens the OpenRig view, and opens a team on this machine as its own Herdr workspace, one tile per seat. Tell the owner where it opened and which tile is the lead.
- A team on another machine: say which machine, and give `ssh -t <mac> "env -u TMUX tmux attach-session -t '=<lead-seat>'"` for the lead.

## 10. Record and report

- Receipt: `<W>/artifacts/ops-receipts/<yyyy-mm-dd>-<slug>.md` listing what was created (project, mission, slices, spec commit, team, machine, qitem or workflow ids, watchdog id) and how to undo each part.
- Report to the owner in 3 to 6 lines: what was set up, which team on which machine, the first task and its id, where to watch, and anything that waits on them.

## Returning to the work

When the owner asks how it is going: read the mission's rows (`rig queue list -A --json` filtered by mission tag), `rig scope --workspace <root> slice ls --mission <m>`, the slice's `proof/` folder (or `rig proof show <mission>/slices/<slice>` for the root project), and the lead's recent transcript. Report what the team produced (branch, commit, PR text, proof), what is next, and what waits on the owner. When a slice finishes, create the next slice or the next wave from the mission intent, route it to the lead the same way, and report it. Stop and ask only when the mission intent itself is done or unclear.
