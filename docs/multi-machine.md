# More than one machine

One Claude Code session with `/rig` can see and drive teams on all your machines. Each machine runs its own OpenRig daemon. Your main machine keeps a list of the others.

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

## 3. Add the other machines on your main machine

On the other machine, get its Tailscale address:

```bash
tailscale ip -4
```

Then, on your main machine, tell `/rig`:

```text
/rig add my other machine "studio" at 100.x.y.z
```

Or do it yourself:

```bash
rig host add --id studio --transport http --url http://100.x.y.z:7433
rig host doctor studio
rig ps --all-hosts
```

`rig host pair <address>` is another way to connect. It asks for one approval on the other machine.

## 4. Optional: SSH, for commands that have no `--host`

Most rig commands accept `--host <id>`. A few do not (for example seat, restore and workflow commands). For those, `/rig` runs the command on the other machine over SSH with its helper `scripts/rig-on`. To allow that:

1. On the other machine, turn on SSH. On macOS: System Settings > General > Sharing > Remote Login.
2. On your main machine, copy your SSH key to it: `ssh-copy-id <user>@<tailscale address>`
3. Check that it works without a password: `ssh -o BatchMode=yes <tailscale address> true`

Without SSH, `/rig` still sees and drives the other machine through `--host`. It tells you when a step needs SSH.

## 5. After a reboot

Start the daemon and bring your teams back on each machine:

```text
/rig bring my rigs back after the reboot
```

or by hand: `rig start --last` (it starts the daemon and restores the rigs that were running).

## Keep the machines the same

- Run `git pull && ./install.sh` on each machine after an update.
- Each machine has its own Herdr settings and its own machine notes in `~/.config/openrig-mod/machine-notes.md`.
- See a team on another machine: `/rig` shows its status here. To watch its terminals, open them on that machine, or use the SSH command `/rig` gives you.
