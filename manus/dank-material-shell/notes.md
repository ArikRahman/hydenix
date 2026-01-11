# Notes — DankMaterialShell (DMS) integration into Hydenix

## Goal
Replace **Noctalia Shell** with **DankMaterialShell** in this Hydenix (NixOS + Home Manager) flake, using DMS’s upstream flake-provided modules rather than maintaining a bespoke user service.

Repo: https://github.com/AvengeMedia/DankMaterialShell

## What “change from noctalia to dank material shell” means (in practice)
- Stop installing/autostarting `noctalia-shell`.
- Add DMS as a flake input.
- Import DMS Home Manager module.
- Enable `programs.dank-material-shell` so DMS starts as your “shell layer” in Wayland sessions.
- (Optional later) enable DMS’s niri integration (keybinds/spawn/includes) once you confirm desired behavior.

## Upstream DMS facts (from their `flake.nix` + modules)
- Flake provides:
  - `homeModules.dank-material-shell` (and `homeModules.default`)
  - `homeModules.niri` (extra niri integration)
  - `nixosModules.dank-material-shell` (and `nixosModules.default`)
- Primary package:
  - `packages.<system>.dms-shell` with main program `dms`
- Typical run command:
  - `dms run` (module uses `dms run --session` for systemd service)
- HM module behaviors (high-level):
  - Enables `programs.quickshell` and installs required packages.
  - Provides a **systemd user service** `dms` when `programs.dank-material-shell.systemd.enable = true`.
  - Ties into `config.wayland.systemd.target` (so it starts with the Wayland session target, not a generic `graphical-session.target`).

## Changes made in this repo (implementation notes)
### 1) Flake input
- Added flake input:
  - `inputs.dms.url = "github:AvengeMedia/DankMaterialShell";`
  - `inputs.dms.inputs.nixpkgs.follows = "nixpkgs";`
- Rationale:
  - We want to consume upstream HM module + package without hand-packaging DMS locally.

### 2) Home Manager wiring
- Imported upstream HM module from DMS:
  - `inputs.dms.homeModules.dank-material-shell`
- Enabled DMS:
  - `programs.dank-material-shell.enable = true;`
  - `programs.dank-material-shell.systemd.enable = true;`

### 3) Remove Noctalia
- `noctalia-shell` was removed from `home.packages` (commented out, not deleted).
- `systemd.user.services.noctalia-shell` was disabled by commenting it out (kept for reference).

#### Mistake log (required)
- What I got wrong earlier:
  - I assumed every shell should be started by a hand-written HM user service.
- How I corrected it:
  - DMS ships an upstream HM module that already provides a `dms` systemd user service, so we should enable that instead of maintaining another unit.

## Current configuration stance / defaults
- DMS is enabled and configured to auto-start in Wayland sessions.
- DMS niri knobs defaulted to “off” for now:
  - `programs.dank-material-shell.niri.enableKeybinds = false;`
  - `programs.dank-material-shell.niri.enableSpawn = false;`
- Rationale:
  - Avoid keybind conflicts until you confirm what should own launcher, lock, etc.

## Potential follow-ups / risks
1) **Build time / cache**
   - DMS builds Go + packages Quickshell resources; might be heavier than a simple app.
   - If builds get slow, consider adding/using a cache (if upstream provides one; none noted here).

2) **Wayland-only**
   - DMS is a Wayland shell; expect it to start only in Wayland sessions.

3) **Compositor integration**
   - DMS supports niri, Hyprland, etc.
   - For niri specifically, DMS provides:
     - keybinds injection (IPC actions)
     - spawn-at-startup support
     - “includes” workaround for niri-flake config includes
   - We left these off to avoid overlap with existing `programs.niri.settings` and Hydenix/HyDE keybind assumptions.

4) **HyDE vs DMS**
   - Running HyDE/Hyprland “desktop glue” plus DMS simultaneously can cause duplication (bars, notifications, portals, etc).
   - If you intend DMS to fully replace “desktop glue,” you may later disable overlapping components.

## Verification workflow
- Run `nix flake check` after edits to confirm evaluation succeeds.
- You will do the actual `nixos-rebuild switch --flake .#hydenix`.

## References
- DMS README: https://github.com/AvengeMedia/DankMaterialShell/blob/main/README.md
- DMS flake outputs: https://github.com/AvengeMedia/DankMaterialShell/blob/main/flake.nix
- HM module entry: `homeModules.dank-material-shell` → `distro/nix/home.nix`
