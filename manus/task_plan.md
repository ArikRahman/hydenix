# Task Plan — Add `sodiboo/niri-flake` to Hydenix (NixOS flake)

## Goal
Integrate the `sodiboo/niri-flake` input into your `dotfiles` flake-based NixOS config so you can run the Niri Wayland compositor (and optionally manage it via Home Manager/system modules), without breaking existing Hydenix setup.

## Constraints / Rules
- Use Manus workflow (this file + `notes.md` + a deliverable markdown).
- Prefer changes in `modules/` and Home Manager when appropriate.
- Don’t run rebuilds. Only `nix flake check` (you’ll run commands yourself).
- Don’t delete lines; comment out and explain when removing behavior.
- If I make a mistake, I must document what I got wrong and the correction.

## Assumptions to Validate
- Your flake entrypoint is `dotfiles/flake.nix`.
- You want Niri available either:
  - as a system session (via NixOS module / display manager session), or
  - as a Home Manager-managed compositor session (depends on what niri-flake provides).
- You may be using Hyprland/HyDE currently; Niri will likely be added alongside, not replacing by default.

## Phase 0 — Decide integration shape (you choose)
1. Add Niri as an optional WM alongside Hyprland (recommended).
2. Replace Hyprland/HyDE with Niri as primary session.
3. Add Niri binaries only (no session/module), for manual launching/testing.

**Decision needed:** which of the above do you want?

## Phase 1 — Research (populate `notes.md`)
- ✅ Confirmed upstream outputs from `sodiboo/niri-flake`:
  - NixOS module: `nixosModules.niri`
  - Home Manager modules:
    - `homeModules.niri`
    - `homeModules.config` (helper; manages `~/.config/niri/config.kdl` when config is provided)
    - `homeModules.stylix` (stylix integration)
  - Packages:
    - `packages.${system}.niri-stable`
    - `packages.${system}.niri-unstable`
    - `packages.${system}.xwayland-satellite-stable`
    - `packages.${system}.xwayland-satellite-unstable`
  - Overlay: `overlays.niri`
- ✅ Confirmed NixOS enable option:
  - `programs.niri.enable = true;`
- ✅ Confirmed cache option (defaults to enabled):
  - `niri-flake.cache.enable` adds `https://niri.cachix.org` substituter + trusted key
- Identify conflicts/overlaps with Hydenix modules (portals, polkit, gnome-keyring, xdg-desktop-portal backends).

## Phase 2 — Implement minimal integration (safe, non-invasive)
### 2.1 Add flake input
- Add an input in `dotfiles/flake.nix`:
  - `niri-flake.url = "github:sodiboo/niri-flake";`
  - Add any `follows` wiring if recommended by upstream.

### 2.2 Wire module into NixOS or Home Manager
Confirmed upstream wiring points:
- NixOS:
  - Import `inputs.niri.nixosModules.niri` in your system `modules = [ ... ]` list.
  - Enable with `programs.niri.enable = true;`
- Home Manager (optional):
  - Import `inputs.niri.homeModules.niri` (or use the NixOS module’s `home-manager.sharedModules` behavior if you’re using home-manager inside NixOS modules).
  - Enable with `programs.niri.enable = true;`

### 2.3 Make Niri available as a package
- If you enable the NixOS module (`programs.niri.enable = true;`), it will install:
  - `xdg-utils`
  - `programs.niri.package` (defaults to `niri-stable`)
  - and register a session via `services.displayManager.sessionPackages = [ cfg.package ];`
- If you only want packages (no module), use:
  - `inputs.niri.packages.${system}.niri-stable` or `...niri-unstable`

## Phase 3 — Add an optional config module (clean structure)
- Create a dedicated module file (deliverable will include exact path once I can edit):
  - `modules/system/niri.nix` (system session) and/or
  - `modules/hm/niri.nix` (user config)
- Add options:
  - `hydenix.system.niri.enable` or `hydenix.hm.niri.enable` (if you want it togglable).
- Keep defaults off so it doesn’t disrupt your current WM unless enabled.

## Phase 4 — Session + Portals + XDG integration
- If you use SDDM (Hydenix does), ensure Niri session appears:
  - Confirm `.desktop` session file handling.
- Configure or avoid conflicts with:
  - `xdg-desktop-portal`
  - `xdg-desktop-portal-gtk` / `-wlr` / compositor-specific portal
- Ensure `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE=wayland`, etc. are correct if needed.

## Phase 5 — Validation steps (you will run)
- Run `nix flake check` and capture output into a log file (per your workflow).
- If errors:
  - Fix 1–2 rounds max.
  - Then hand back actionable guidance for you.

## Deliverables
1. `dotfiles/manus/notes.md` — key findings from niri-flake docs, chosen integration path, pitfalls.
2. `dotfiles/manus/niri_integration.md` — final “what changed + how to enable + how to switch sessions”.
3. Code changes (once tools available again):
   - `dotfiles/flake.nix` updated with new input and module wiring.
   - New module(s) under `dotfiles/modules/system/` and/or `dotfiles/modules/hm/`.

## Open Questions (answer before Phase 2)
1. Do you want Niri *alongside* Hyprland/HyDE, or to *replace* it?
2. Are you starting sessions via SDDM (likely) or something else?
3. Do you want Home Manager to manage Niri config, system config, or both?