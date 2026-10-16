# More than one machine

Your machines form one fleet. Each machine runs its own OpenRig daemon and lists every other machine. A `/rig` on any machine sees and drives the teams on all of them, and keeps the kernel running on every machine that is online.

## 1. Put the machines on one private network

Install [Tailscale](https://tailscale.com/download) on each machine and sign in to the same account. Check that each machine sees the others:

```bash
tailscale status
```

The OpenRig daemon listens on `127.0.0.1` and on the machine's Tailscale address by default. Machines on your Tailscale network can reach it without a token.

> **Security:** every device on your Tailscale network can then control the agents on these machines. Keep only your own devices on that network, or limit access with Tailscale access rules.

## 2. Install on every machine

On each machine:

```bash
git clone https://github.com/genius8267/Openrig-Mod.git
cd Openrig-Mod
./install.sh
```

On a machine that only runs teams for your main machine, you can use `./install.sh --no-kernel`. Then that machine runs the daemon without OpenRig's kernel team.

The daemon finds the Tailscale address when it starts. If Tailscale was not running at that time, restart the daemon:

```bash
rig daemon stop && rig daemon start
```

## 3. Make one fleet: every machine lists the others

On each machine, add every other machine. Give a machine the same id on every machine. Use its MagicDNS name, not its address, so the entry still works when the address changes. `tailscale status --json` shows each machine's `DNSName`.

Tell `/rig`:

```text
/rig add my other machine "studio"
```

Or do it yourself:

```bash
rig host add --id studio --transport http --url http://studio.<tailnet>.ts.net:7433
rig host doctor studio
rig ps --host studio
```

Keep `host.selected` at `local` on every machine (`rig config get host.selected`). `/rig` reaches the other machines with `--host <id>`. A selected remote host sends your plain `rig` commands to that machine.

`rig host pair <address>` is another way to connect. It asks for one approval on the other machine.

## 4. Optional: SSH, for commands that have no `--host`

Most rig commands accept `--host <id>`. A few do not (for example seat, restore and workflow commands). For those, `/rig` runs the command on the other machine over SSH with its helper `scripts/rig-on`. To allow that:

1. On the other machine, turn on SSH. On macOS: System Settings > General > Sharing > Remote Login.
2. On your main machine, copy your SSH key to it: `ssh-copy-id <user>@<tailscale address>`
3. Check that it works without a password: `ssh -o BatchMode=yes <tailscale address> true`

With SSH, `/rig` also starts a machine whose daemon gives no answer (`rig start --last` on that machine) and heals the agents there.

Without SSH, `/rig` still sees and drives the other machine through `--host`. It tells you when a step needs SSH.

## 5. After a reboot

Type `/rig`. On every online machine it starts the daemon and the kernel, and it restores the rigs on the "Keep running" line of that machine's notes. Machines that Tailscale reports offline are skipped.

By hand: `rig start --last` on each machine (it starts the daemon and restores the rigs that were running).

## Keep the machines the same

- Each `/rig` checks every online machine: the daemon version, the kernel, the rigs to keep running, and stuck agents.
- Run `git pull && ./install.sh` on each machine after an update.
- Each machine has its own Herdr settings and its own machine notes in `~/.config/openrig-mod/machine-notes.md`.
- See a team on another machine: `/rig` shows its status here. To watch its terminals, open them on that machine, or use the SSH command `/rig` gives you.
- See another machine's dashboard here: `OPENRIG_URL=http://studio.<tailnet>.ts.net:7433 rig tui`.
