# Task Plan — Switch from Noctalia Shell to DankMaterialShell (DMS)

## Goal
Replace the current Noctalia-based “shell” autostart setup with **DankMaterialShell** (DMS) in the Hydenix flake, using DMS’s upstream flake + Home Manager module so startup is managed cleanly and declaratively.

Target repo: `dotfiles/` (Hydenix flake)

---

## Phase 0 — Constraints / Guardrails
- Prefer Home Manager integration (modules under `modules/hm/`) unless something truly requires system-level changes.
- Avoid deleting previous work; comment out old Noctalia service/config and leave a note explaining why it was replaced (and what was wrong before, if applicable).
- Validate with `nix flake check` only (you run rebuild yourself later).

---

## Phase 1 — Discovery / Inputs
### 1.1 Confirm current state
- Locate any references to:
  - `noctalia-shell` in `home.packages`
  - custom `systemd.user.services.noctalia-shell`
  - any “theme” references that were actually “shell” autostart wiring (don’t conflate HyDE themes with desktop shells)

### 1.2 Identify DMS integration path
- Use upstream DMS flake outputs:
  - `inputs.dms.homeModules.dank-material-shell`
  - `programs.dank-material-shell.enable = true;`
  - `programs.dank-material-shell.systemd.enable = true;` to autostart DMS in a Wayland session

Deliverable of this phase:
- A short note in `notes.md` summarizing where Noctalia is currently wired, and which DMS module/options will replace it.

Status: ✅ Done / ⬜ Not started

---

## Phase 2 — Implement the switch (Nix edits)
### 2.1 Add DMS flake input
- Edit `flake.nix`:
  - Add `inputs.dms.url = "github:AvengeMedia/DankMaterialShell";`
  - Make it follow `nixpkgs` if that’s your pattern.

### 2.2 Import Home Manager module
- Edit `modules/hm/default.nix`:
  - Add to `imports` list: `inputs.dms.homeModules.dank-material-shell`

### 2.3 Enable DMS + autostart
- In `modules/hm/default.nix`:
  - Configure:
    - `programs.dank-material-shell.enable = true;`
    - `programs.dank-material-shell.systemd.enable = true;`

### 2.4 Remove/disable Noctalia
- Comment out (do not delete):
  - `systemd.user.services.noctalia-shell` definition
- Remove `noctalia-shell` from `home.packages` (or comment it out with a note explaining replacement).

### 2.5 Optional: Niri integration knobs
- Keep conservative defaults unless you explicitly request otherwise:
  - `programs.dank-material-shell.niri.enableKeybinds = false;`
  - `programs.dank-material-shell.niri.enableSpawn = false;`

Deliverable of this phase:
- DMS is enabled via upstream HM module, Noctalia autostart is disabled, and Noctalia is no longer installed by HM.

Status: ✅ Done / ⬜ Not started

---

## Phase 3 — Validation
### 3.1 Evaluate flake
- Run `nix flake check` in `dotfiles/`
- If evaluation errors occur:
  - Fix in 1–2 iterations max, then stop and request user guidance (per project rules).

### 3.2 Sanity review (no rebuild here)
- Confirm:
  - HM module import doesn’t conflict with existing module imports
  - No duplicate service names / option declarations
  - DMS autostarts via systemd user unit provided by the module

Deliverable of this phase:
- `nix flake check` passes.

Status: ✅ Done / ⬜ Not started

---

## Phase 4 — Handoff / Next Steps for You
After you pull the changes and you’re ready to apply:
- Run your normal command:
  - `z dotfiles; sudo nixos-rebuild switch --flake .#hydenix`

Post-apply checklist:
- Verify DMS is running:
  - check user services for `dms`
- If DMS grabs keys or conflicts:
  - decide whether to gate it to only start under Niri, or keep it global across all Wayland sessions.

Status: ⬜ Not started

---

## Open Questions (only if you want additional tuning)
1. Should DMS run in **all Wayland sessions**, or **only under Niri**?
2. Do you want DMS to manage **Niri keybinds** (`enableKeybinds`) or just run as the shell and keep your existing binds?
3. Do you want DMS to handle notifications/launcher/lockscreen (its “replace everything” model), or should HyDE/Hyprland still own some components?