# Hydenix Project Context for AI Agents

## Project Overview
Hydenix is a NixOS configuration template using Flakes. It allows users to customize their NixOS setup, add packages, and configure themes. Based off https://github.com/richen604/hydenix

## Key Files and Directories

- **flake.nix**: The entry point for the Nix Flake. Defines inputs and outputs.
- **configuration.nix**: The main NixOS system configuration file.
- **hardware-configuration.nix**: Hardware-specific settings, usually auto-generated.
- **modules/**: Contains custom modules.
  - **hm/**: Home Manager modules.
  - **system/**: System-level NixOS modules.
- **docs/**: Documentation files.

## Development Guidelines

- When modifying configuration, prefer editing for home manager, or files in `modules/`.
- Ensure `flake.nix` is updated if new inputs are required.
- Follow Nix language best practices.
- Comment thoroughly on why you're adding something
- everytime you make a mistake, comment what you got wrong and how you corrected it
- instead of debugging from terminal, dump output into log text file workflow
- stop deleting lines, and rather, comment them out and make note of why you are getting rid of them
- if i have to do a command, the goal of nix is to make things reproducible. make note of it in appendix.md
- if you're troubleshooting, use troubleshooting.md to log complex things

## Decision Log / Gotchas

### Steam external disk + Proton prefixes: UID ownership must match
- Symptom: Steam game launches then immediately stops; logs show:
  - `wine: '<steamapps>/compatdata/<appid>/pfx' is not owned by you`
- Root cause: The Steam library lives on an ext4 filesystem whose on-disk ownership is by numeric UID. If the user account UID changes (or differs from the UID that created the SteamLibrary), Proton/Wine refuses to use the prefix.
- Project decision: Standardize the primary user `hydenix` to **UID 1000** to match existing external disk ownership (many SteamLibrary paths were owned by UID 1000).
- Rationale: This avoids expensive/risky recursive `chown -R` across a large Steam library and makes ownership stable across desktop environments (Hyprland/Plasma) and mount mechanisms.
- Future conflict warning:
  - If you ever create/recreate users, ensure `users.users.hydenix.uid = 1000;` remains true.
  - If another account already uses UID 1000, resolve that conflict before rebuilding (either migrate that account or pick a consistent UID and migrate disk ownership intentionally).

- > z hydenix; sudo nixos-rebuild switch --flake .#hydenix 
- ^ command to update nixos
- personal notes
  - to make external drive work, may have to ```sudo chown -R hydenix:users /mnt/arik_s_disk/SteamLibrary/steamapps/compatdata```
  -dota 2 audio cuts out whenf inding match, fix with launch option ```-sdlaudiodriver pulse```
