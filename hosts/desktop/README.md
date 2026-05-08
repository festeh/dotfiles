# desktop — Arch install

Target: PC with Nvidia RTX 3090, hostname `desktop`, user `dima`.

## Files

- `archinstall.json` — disk layout, packages, services, locale (committed)
- `archinstall-creds.json` — root + user passwords, **sops/age encrypted** (committed)
- `config.toml` — placeholder for the Installer (Go) tool, fill in after first run

## Before booting the USB on the desktop

1. Confirm the disk device. On the live boot, run `lsblk`. If it's not `nvme0n1`, edit `disk_config.device_modifications[0].device` in `archinstall.json`.
2. Bring the age private key with you. The encrypted creds can only be decrypted with `~/.config/sops/age/keys.txt` from your laptop. Copy it onto the Ventoy USB (Ventoy data partition) before booting, e.g. to `/age-keys.txt` — it's a public USB so don't leave it there long-term.

## Installing

Boot the Ventoy USB → pick the Arch ISO. From the live shell:

```sh
# pull dotfiles + tools
pacman -Sy --noconfirm git sops age
git clone https://github.com/festeh/dotfiles /tmp/dot

# decrypt creds (age key from the Ventoy partition)
mount /dev/disk/by-label/Ventoy /mnt
export SOPS_AGE_KEY_FILE=/mnt/age-keys.txt
sops -d /tmp/dot/hosts/desktop/archinstall-creds.json > /tmp/creds.json

# run archinstall
archinstall \
  --config /tmp/dot/hosts/desktop/archinstall.json \
  --creds  /tmp/creds.json \
  --silent

# scrub the decrypted creds
shred -u /tmp/creds.json
```

## After install

Reboot. Log in as `dima`. Then:

```sh
~/bootstrap.sh   # downloaded by archinstall custom_commands
```

That clones dotfiles + Installer and sets the rest up.

## Notes

- **nvidia-open** is used (kernel module for Turing+, RTX 3090 = Ampere). Pre-built for stock `linux` kernel, no DKMS rebuild on kernel updates.
- **btrfs** with subvolumes `@`, `@home`, `@log`, `@pkg`, `@.snapshots` — same layout as your laptop. Mount opts: `compress=zstd,ssd,noatime`.
- **systemd-boot** as bootloader. Entries live in `/boot/loader/entries/`.
- `custom_commands` block sets `nvidia_drm.modeset=1`, adds nvidia modules to mkinitcpio early-load (KMS at boot, required for Wayland/Hyprland later), and rebuilds initramfs.
- archinstall config schema is version-tied. If a future ISO rejects this file, regenerate via interactive archinstall → "Save configuration" and diff against this one.

## Editing creds

```sh
cd ~/dotfiles
sops hosts/desktop/archinstall-creds.json    # opens decrypted in $EDITOR, re-encrypts on save
```

`.sops.yaml` at the repo root maps `hosts/*/archinstall-creds.json` to your age public key (`age1xmxlss…`). New per-host creds files match the same rule automatically — just `sops -e -i` them after creating.
