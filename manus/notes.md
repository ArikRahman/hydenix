# Notes — Add `sodiboo/niri-flake` to Hydenix (NixOS flake)

## Goal
Add the Niri compositor via the flake `github:sodiboo/niri-flake` into this Hydenix-based NixOS configuration, in a way that is:
- Flake-native (input added to `flake.nix`)
- Implemented via a module (prefer `modules/system/` or `modules/hm/`)
- Compatible with `nix flake check`
- Easy to toggle on/off (don’t disrupt your current Hyprland/HyDE session unless you opt in)

## Context I know from this repo
- Project root: `dotfiles/`
- This is a Hydenix template; `flake.nix` defines inputs and builds the system with `inputs.hydenix.inputs.nixpkgs.lib.nixosSystem`.
- Home Manager config exists under `modules/hm/default.nix`.

## Upstream: `sodiboo/niri-flake` outputs (verified)
From upstream `flake.nix`, the important outputs/entrypoints are:

### Packages
- `packages.${system}.niri-stable`
- `packages.${system}.niri-unstable`
- `packages.${system}.xwayland-satellite-stable`
- `packages.${system}.xwayland-satellite-unstable`

So in **your** flake, you can refer to:
- `inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-stable` (or `niri-unstable`)

### NixOS module
- `nixosModules.niri`

Enables via:
- `programs.niri.enable = true;`

Extra upstream option:
- `niri-flake.cache.enable` (default `true`) — configures binary cache:
  - substituter: `https://niri.cachix.org`
  - trusted key: `niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=`

What the module does when enabled (high level):
- installs `xdg-utils` + `programs.niri.package`
- registers session: `services.displayManager.sessionPackages = [ cfg.package ];`
- enables common Wayland plumbing:
  - `xdg.portal.enable = true`
  - adds `xdg-desktop-portal-gnome` when screencast support is enabled in the build
  - sets `xdg.portal.configPackages = [ cfg.package ]` (so niri’s portal config is included)
- enables:
  - `security.polkit.enable = true` and starts a polkit agent (kde polkit agent) as a user service
  - `services.gnome.gnome-keyring.enable = true`
  - `programs.dconf.enable`, `fonts.enableDefaultPackages`, `hardware.graphics.enable`

Important detail:
- It sets `disabledModules = [ "programs/wayland/niri.nix" ];` to avoid conflicts with nixpkgs’ own `niri` module.

### Home Manager modules
- `homeModules.niri` (adds a HM option `programs.niri.enable`)
- `homeModules.config` (internal helper; manages `~/.config/niri/config.kdl` when `finalConfig` is provided)
- `homeModules.stylix` (stylix integration)

Both NixOS and HM modules use the option namespace:
- `programs.niri.*`

## Integration approach I recommend for your Hydenix setup
### Keep it minimal (install + session), default OFF
1. Add the flake input `niri` pointing at `github:sodiboo/niri-flake`.
2. Import `inputs.niri.nixosModules.niri` into your system evaluation.
3. Create a small local module (ex: `modules/system/niri.nix`) that:
   - exposes a simple toggle you control (ex: `hydenix.system.niri.enable`)
   - when enabled, sets `programs.niri.enable = true;`
   - optionally pins `programs.niri.package` to stable/unstable
   - optionally keeps `niri-flake.cache.enable = true` (default) or allows disabling it

This keeps Niri installed and selectable in SDDM (via `sessionPackages`) without replacing Hyprland.

## Risks / gotchas to watch for (specific to niri-flake)
- Portals: the module enables `xdg.portal` and may add `xdg-desktop-portal-gnome`.
  - If Hydenix/HyDE currently uses a different portal backend, you may need to reconcile which extra portal(s) you want.
- Polkit + keyring: module enables polkit + gnome-keyring; if you already enable these elsewhere, it should merge, but watch for duplicates/conflicts.
- Cache: enabling the substituter/key is usually fine, but if you manage `nix.settings.substituters` strictly elsewhere, you’ll want to review the merge or disable `niri-flake.cache.enable`.

## Open questions (to decide final wiring)
- Do you want Niri alongside Hyprland/HyDE (recommended), or do you want to switch fully?
- Stable or unstable (`niri-stable` vs `niri-unstable`)?

## Validation (you run)
- Run `nix flake check` and save output into a log file (your workflow).
  - If failure: likely causes are missing module import in the system modules list, or naming mismatch (`inputs.niri.nixosModules.niri` must match exactly).

## Mistake & correction log
- Mistake: I originally noted “missing upstream outputs” and suggested they might be `nixosModules.default` / `packages.${system}.default`.
- Correction: `sodiboo/niri-flake` actually exports `nixosModules.niri` and packages like `packages.${system}.niri-stable` / `niri-unstable`.
