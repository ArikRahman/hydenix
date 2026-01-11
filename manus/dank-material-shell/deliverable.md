# Deliverable: Switch from Noctalia to DankMaterialShell (DMS)

## Goal

Replace the previously configured **Noctalia Shell** autostart setup with **DankMaterialShell** (https://github.com/AvengeMedia/DankMaterialShell), so your Wayland sessions use DMS as the “shell layer” instead of Noctalia.

This change is implemented **Home Manager-first** (consistent with Hydenix guidance), using DMS’s upstream flake module rather than a bespoke user unit.

---

## What Changed

### 1) Added DMS as a flake input
- Added a new flake input named `inputs.dms` pointing to:
  - `github:AvengeMedia/DankMaterialShell`
- Set `inputs.dms.inputs.nixpkgs.follows = "nixpkgs"` to keep nixpkgs consistent with the rest of your configuration.

**Why**
- DMS provides its own flake outputs (packages + `homeModules` + `nixosModules`).
- Using the upstream module prevents drift and reduces maintenance burden.

---

### 2) Imported the upstream Home Manager module for DMS
In your Home Manager module (`dotfiles/modules/hm/default.nix`), the DMS module is imported:

- `inputs.dms.homeModules.dank-material-shell`

**Why**
- This enables the `programs.dank-material-shell.*` option namespace.
- The upstream module also provides a robust systemd user service definition (`dms`) when enabled.

---

### 3) Replaced Noctalia autostart with DMS autostart
Previously you had:
- `home.packages` including `noctalia-shell`
- `systemd.user.services.noctalia-shell` with `ExecStart = .../noctalia-shell`

Now:
- The Noctalia package entry was removed (commented note left in place for context).
- The entire `systemd.user.services.noctalia-shell` block was **commented out** (not deleted), with an explanation note.
- DMS is enabled using the upstream module:

- `programs.dank-material-shell.enable = true;`
- `programs.dank-material-shell.systemd.enable = true;`

**Why**
- DMS already ships a Home Manager unit designed to start with the Wayland session target.
- This is less error-prone than maintaining a custom unit and keeps you aligned with upstream behavior.

---

## Notes on “What I got wrong” (intentional project rule compliance)

Earlier I treated “shell autostart” as something we needed to hand-roll for each shell. That was correct for Noctalia (no dedicated upstream HM service in your config), but for DMS it’s unnecessary because DMS provides an upstream HM module that already manages:
- required packages
- a `systemd --user` service (`dms`) bound to the compositor session target

Correction: switch to the upstream module + enable its systemd integration.

---

## Current Behavior

- DMS should start automatically in your Wayland graphical session via the upstream Home Manager unit when Home Manager activates.
- Noctalia is no longer installed by `home.packages`, and its autostart unit is disabled (commented out).

---

## Follow-ups / Verification

### Run evaluation checks
Per your workflow, use:
- `nix flake check`

### Apply changes (you do this)
Per your workflow:
- `z dotfiles; sudo nixos-rebuild switch --flake .#hydenix`

---

## Optional Next Steps (if you want tighter integration)

1) **Niri integration (optional)**
DMS also provides a `homeModules.niri` integration for binds/spawn/includes. Right now the config is conservative:
- `programs.dank-material-shell.niri.enableKeybinds = false;`
- `programs.dank-material-shell.niri.enableSpawn = false;`

If you want DMS to manage Niri keybinds or auto-spawn via Niri config, we can turn these on intentionally and reconcile overlaps with your existing binds.

2) **Disable DMS autostart outside specific compositors**
If you want DMS only under Niri (and not Hyprland/others), we can gate the unit (or switch strategy to compositor startup) depending on how your sessions are started.

3) **DMS configuration**
The upstream module supports writing:
- `~/.config/DankMaterialShell/settings.json`
- `~/.config/DankMaterialShell/clsettings.json`
- `~/.local/state/DankMaterialShell/session.json`

We can add minimal defaults once you tell me what you want configured first (launcher keybind behavior, notifications, wallpaper theming, etc.).