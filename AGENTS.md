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

- > z hydenix; sudo nixos-rebuild switch --flake .#hydenix 
- ^ command to update nixos