# iDar OS — Base System Bootstrap & Rootfs

Minimal, robust, and compliant root filesystem deployment image for **iDar OS** running on top of the **Loom Microkernel**.

This repository contains the golden deployment artifacts, the standalone base image, and the automated bootstrapping utility for CC:Tweaked systems.

---

## Quick Start: Automated Installation

Bootstrapping iDar OS requires an active HTTP API environment (Wireless Modem / Network Interface). Execute the one-line bootstrapper directly from the CraftOS shell:

```lua
wget run https://raw.githubusercontent.com/DarThunder/iDar-OS/refs/heads/main/installer.lua

```

The installer will automatically:

1. Initialize the canonical **FHS** directory layout (`/bin`, `/sbin`, `/lib`, `/etc`, `/var`, `/tmp`, `/proc`, `/sys`).
2. Download and decompress the single-payload `rootfs.dmb` distribution image.
3. Import the system developer public keys into `/etc/pacman.d/keys/` to establish the cryptographic trust chain.
4. Deploy the Master Boot Record (`startup.lua`) pointing to `/iDar/boot/MBR.lua`.

After installation completes, reboot your terminal to enter **iDar OS**.

---

## Current Development Status: Package Ecosystem

> **Important Notice:**
> The remote package repositories and the dynamic package manager backend (`pacman -S`) are currently transitioning to the **SATDv3 standard**. Package fetching from remote mirrors is disabled while registry stabilization is underway.

**However, the operating system is functional out of the box.** (Maybe lmao)

The base system includes a full suite of essential userland tools:

- **Coreutils:** `ls`, `cat`, `mkdir`, `mv`, `rm`, `touch`
- **Shell & Terminal:** `dsh` (with `/etc/profile` and custom environment configuration)
- **Authentication & Security:** PAM-like userland (`login`, `passwd`, `sudo`, `/etc/shadow`, `/etc/passwd`)
- **Cryptography & Compression Engine:** `signify` (secp256k1 signing/verification), `dmb` (LZ77 pack/unpack), `dssl`
- **System Utilities:** `vi` text editor, `fastfetch` hardware & OS inspector

---

## Repository Structure

- `installer.lua` — Lightweight, standalone bootstrap script with embedded LZ77/IDMB unpacker.
- `rootfs.dmb` — The pre-compiled, compressed golden rootfs image used by the bootstrapper.
- `rootfs/` — The raw, auditable source tree of the base system for manual inspection, debugging, or custom hacking.

---

## Initial Access

On first boot:

- **Default User:** `root`
- **Password:** Leave blank (press `Enter`).
- Set your administrative password immediately after login by executing:

```sh
passwd root

```

---

## Manual Installation (Advanced)

If you prefer to inspect and manually install the operating system without using the pre-compiled `.dmb` image:

1. Clone the contents of `rootfs/` directly into `/iDar/` on your target storage drive.
2. Ensure directory attributes match `/etc/permissions.conf`.
3. Create your `startup.lua` at the CraftOS root pointing to the bootloader:

```lua
local boot = require("iDar.boot.MBR")

```
