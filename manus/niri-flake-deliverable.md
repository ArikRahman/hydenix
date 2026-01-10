# Niri flake integration (`sodiboo/niri-flake`) — deliverable

## What you asked for

You wanted `https://github.com/sodiboo/niri-flake` added to your Hydenix-based NixOS flake.

This deliverable documents the **exact integration** that was implemented in your repo:
- a new flake input (`inputs.niri`)
- importing the upstream NixOS module (`inputs.niri.nixosModules.niri`)
- a small, toggleable local system module (`hydenix.system.niri`) so you can turn Niri on/off cleanly
- notes on how to validate with `nix flake check` and how to enable

---

## Upstream interface (verified)

From `sodiboo/niri-flake`:

- NixOS module: `nixosModules.niri`
- Enable option: `programs.niri.enable = true;`
- Packages:
  - `packages.${system}.niri-stable`
  - `packages.${system}.niri-unstable`
- Cache option (default enabled upstream): `niri-flake.cache.enable`

The upstream NixOS module, when enabled, also:
- installs `xdg-utils` + `programs.niri.package`
- registers a display manager session via `services.displayManager.sessionPackages = [ cfg.package ];`
- sets up portals (`xdg.portal.*`) and may add `xdg-desktop-portal-gnome` depending on build features
- enables `security.polkit.enable = true` and sets up a polkit agent user service
- enables `services.gnome.gnome-keyring.enable = true`
- disables the nixpkgs module `programs/wayland/niri.nix` to avoid conflicts

---

## What changed in *your* repo

### 1) Flake input added + module wired into system evaluation

File: `dotfiles/flake.nix`

- Added input `niri` pointing to `github:sodiboo/niri-flake`
- Wired `niri`’s nixpkgs to follow your flake’s `nixpkgs` input:
  - `inputs.niri.inputs.nixpkgs.follows = "nixpkgs";`
- Imported upstream NixOS module into the system module list:
  - `inputs.niri.nixosModules.niri`

Result: the `programs.niri.*` options are available to your system configuration.

---

### 2) New local module: `hydenix.system.niri`

File: `dotfiles/modules/system/niri.nix` (new)

This module exists so **you** control Niri with a single toggle, without spreading config throughout `configuration.nix`.

It adds the option namespace:

- `hydenix.system.niri.enable` (default: module provides option; you choose value in `configuration.nix`)
- `hydenix.system.niri.channel` (`"stable"` or `"unstable"`, default `"stable"`)
- `hydenix.system.niri.enableCache` (bool, default `true`)

When enabled, it sets:

- `programs.niri.enable = true;`
- `programs.niri.package = inputs.niri.packages.${system}.niri-stable|niri-unstable;` based on `channel`
- `niri-flake.cache.enable` based on `enableCache` (as a default)

This is intentionally **non-invasive**:
- It does **not** disable Hyprland/HyDE.
- It does **not** force Niri as the default session.
- It simply makes Niri available (and session-registered by upstream) so you can select it at login.

---

### 3) System module set now imports Niri module

File: `dotfiles/modules/system/default.nix`

- Added `./niri.nix` to the `imports = [ ... ];` list, with comments describing why.

---

### 4) Niri is off by default in your host config

File: `dotfiles/configuration.nix`

- Added:

  - `hydenix.system.niri.enable = false;`

…and commented examples for:
- `hydenix.system.niri.channel`
- `hydenix.system.niri.enableCache`

This keeps your current setup stable until you explicitly opt in.

---

## How to enable Niri

Edit `dotfiles/configuration.nix` and set:

- `hydenix.system.niri.enable = true;`

Optional:
- `hydenix.system.niri.channel = "stable";` (default) or `"unstable"`
- `hydenix.system.niri.enableCache = true;` (default) or `false`

After enabling, the upstream module should register a Niri session with your display manager via:
- `services.displayManager.sessionPackages = [ cfg.package ];`

If you use SDDM (common in Hydenix), you should be able to select **Niri** at the login session chooser.

---

## Validation (no rebuild from me)

Per your rules, validate with:

- `nix flake check`

If there’s a failure, the most likely causes are:
- `inputs` not being passed into a module that references it
  - (This repo already passes `specialArgs = { inherit inputs; };` in `dotfiles/flake.nix`, so `modules/system/niri.nix` can use `inputs`.)
- an evaluation conflict with portal/polkit/keyring if something else forces different settings
- strict `nix.settings.substituters` policy conflicts (if you have hard overrides elsewhere)
  - In that case, set `hydenix.system.niri.enableCache = false;` and manage caches yourself.

---

## Mistake & correction note (engineering log)

- Initially, before reading upstream, I assumed the module might be `nixosModules.default` and the package might be `packages.${system}.default`.
- After reading upstream `flake.nix`, I corrected this:
  - module is `nixosModules.niri`
  - packages are `packages.${system}.niri-stable` / `niri-unstable`

This repo’s integration uses the correct upstream names.

---

## Summary

You now have:
- `inputs.niri` in `dotfiles/flake.nix`
- upstream Niri module imported into your system
- a clean toggle: `hydenix.system.niri.enable`
- stable/unstable selection support
- optional Cachix enable/disable

Next action for you:
1. Set `hydenix.system.niri.enable = true;`
2. Run `nix flake check` (save output to a log file per your workflow)
3. Rebuild on your side when you’re ready