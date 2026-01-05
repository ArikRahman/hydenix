# Hydenix Project Context for AI Agents, an index for referencing relevant project documents

## Project Overview
Hydenix is a NixOS configuration template using Flakes. It allows users to customize their NixOS setup, add packages, and configure themes. Based off https://github.com/richen604/hydenix
My repo is https://github.com/ArikRahman/hydenix

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
- be conservative about deleting lines, and rather, comment them out and make note of why you are getting rid of them. get rid of clutter and revise comments as necessary though. be precise
- if i have to do a command, the goal of nix is to make things reproducible. make note of it in appendix.md
- if you're troubleshooting, use troubleshooting.md to log complex things
- im using nushell btw. use semicolons and other nushell syntax 

## Decision Log / Gotchas


- > z hydenix; sudo nixos-rebuild switch --flake .#hydenix 
- ^ command to update nixos
- personal notes
  - to make external drive work, may have to ```sudo chown -R hydenix:users /mnt/arik_s_disk/SteamLibrary/steamapps/compatdata```
  -dota 2 audio cuts out whenf inding match, fix with launch option ```-sdlaudiodriver pulse```
