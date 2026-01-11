# Niri flake integration (`sodiboo/niri-flake`) — Home Manager-first + Noctalia Shell

## Goal

Configure Niri using **Home Manager** as the primary source of truth, and run **Noctalia Shell** as the “shell layer” inside your graphical session.

You specifically asked:
- “i want everything managed via home manager”
- “switch niri to use noctalia-shell”

This document describes what was changed, how to enable it, and an important limitation about SDDM session selection.

---

## Summary of the approach

### What “Home Manager-first” means here

Home Manager will manage:
- Installing `niri` and `noctalia-shell` as user packages
- Niri configuration (`~/.config/niri/config.kdl`) via `programs.niri.settings`
- Launching `noctalia-shell` automatically as a `systemd --user` service

### Important limitation: SDDM session list

If you want “Niri” to appear in SDDM’s session chooser *the same way Plasma does*, that is typically **system-level** because SDDM reads session `.desktop` files from system paths (e.g. `/run/current-system/sw/share/wayland-sessions`).

Home Manager can:
- manage configs and user services
- let you launch Niri manually (TTY: `niri`/`niri-session`, or from an existing session)

Home Manager typically cannot:
- reliably install/register display-manager session entries the same way system modules do

**Practical implication:** With HM-only, you may not see “Niri” in SDDM even if Niri is installed and configured. If you want SDDM integration, keep/enable the NixOS-side session registration from `niri-flake`’s NixOS module.

---

## Upstream reference (verified)

`sodiboo/niri-flake` provides:
- Home Manager module: `inputs.niri.homeModules.niri`
- Preferred config path: `programs.niri.settings` (build-time validated into `~/.config/niri/config.kdl`)
- Packages:
  - `inputs.niri.packages.${system}.niri-stable`
  - `inputs.niri.packages.${system}.niri-unstable`

The upstream README explicitly recommends:
- Use `programs.niri.settings` for config
- Use their binary cache `https://niri.cachix.org` for faster installs

---

## What changed in this repository (HM-first)

### 1) Import `niri-flake` Home Manager module

In your Home Manager module (`dotfiles/modules/hm/default.nix`) we import:

- `inputs.niri.homeModules.niri`

Why:
- Adds `programs.niri.*` HM options
- Enables declarative Niri configuration and build-time validation

---

### 2) Enable Niri via Home Manager

In `dotfiles/modules/hm/default.nix`, we configure:

- `programs.niri.enable = true;`
- `programs.niri.package = inputs.niri.packages.${system}.niri-stable;` (defaulted to stable to avoid surprise “compile forever” events from unstable)
- `programs.niri.settings.environment."NIXOS_OZONE_WL" = "1";` (useful for Electron apps under Wayland)

Notes:
- This is intentionally “minimal config”; you can add more `programs.niri.settings` entries later.
- `niri-stable` is chosen because you observed large Rust compiles when building `niri-unstable`.

---

### 3) Run Noctalia Shell automatically (Home Manager user service)

In `dotfiles/modules/hm/default.nix`, we define a user service:

- `systemd.user.services.noctalia-shell`

It:
- Starts as part of `graphical-session.target`
- Runs `${pkgs.noctalia-shell}/bin/noctalia-shell`
- Restarts on failure

This is the practical way to make Noctalia behave like your “shell UI layer” while using Niri (and also in other graphical sessions).

**If you want it to run only under Niri:** we can tighten the unit’s `WantedBy`/`PartOf` to a Niri-specific unit/target, but that depends on how your session is started and which user units exist at runtime.

---

## How to use

### If you are OK launching Niri manually (HM-only)

1. Ensure the system has Niri available (HM config takes care of the user side on activation).
2. Launch Niri from a TTY session:
   - `niri` or `niri-session` (depending on what is available in PATH)

Once Niri starts:
- Home Manager-managed `noctalia-shell` service will start on `graphical-session.target` in your user session.

### If you want Niri in SDDM session chooser (like Plasma)

Keep the NixOS-side session registration from the upstream NixOS module (`inputs.niri.nixosModules.niri`) so it puts the session `.desktop` file in the system session path.

You can still keep **all user config** in Home Manager:
- Niri config (`programs.niri.settings`)
- Noctalia Shell user service
- launchers/bars/etc.

This “hybrid” is the typical setup:
- system installs/registers the session
- home-manager manages the user experience

---

## Notes / gotchas

- Niri isn’t “a desktop environment” like Plasma; it’s a compositor. Your “desktop shell” experience comes from:
  - shell layer (`noctalia-shell`)
  - launcher (`fuzzel`)
  - wallpaper (`swaybg`)
  - bar / notifications (optional: `waybar`, `mako`, etc.)

- If you see big compiles again:
  - double-check you’re using `niri-stable` (not unstable)
  - ensure you’re using the binary cache (if you’ve enabled it in your Nix settings)

---

## Mistake & correction log (engineering hygiene)

- Mistake: Earlier I treated SDDM session visibility as something Home Manager could guarantee.
- Correction: Session registration for display managers is normally system-level; HM reliably manages user packages/config/services, but not SDDM session discovery.

---

## Next steps (optional improvements)

- Add more `programs.niri.settings` (outputs, keybinds, input, layout).
- Refine Noctalia Shell service to run only under Niri (if you confirm your session start method and available user targets).
- Add `mako`/`waybar` with `systemd.user.services.*` if you want a full desktop stack.