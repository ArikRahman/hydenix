# Task Plan — Fix suspend/resume black screen (repeating underscore) on Hydenix (NixOS)

## Goal
Make suspend/resume reliable on this Hydenix NixOS flake. Current failure mode: resume ends on a screen with a repeating underscore; cannot switch TTYs (Ctrl+Alt+F3 doesn’t work). This suggests a kernel/graphics resume failure that may fully wedge input/display, not just a compositor crash.

## Success criteria
- Suspend → resume returns to a usable graphical session or at least a usable login screen.
- If resume fails, system still allows recovery (TTY switch and/or SSH) without hard power cycle.
- Changes are declarative and checked with `nix flake check`.

## Constraints / Project rules
- Use Manus workflow: `task_plan.md`, `notes.md`, and final deliverable doc(s) in `dotfiles/manus/suspend-fix/`.
- Don’t run `nixos-rebuild` (user will do that). Use `nix flake check` only.
- Prefer edits in `modules/` (system modules first).
- Be conservative about deleting lines: comment-out with explanation instead.
- Log troubleshooting in `troubleshooting.md` and keep research findings in `notes.md`.
- Use Nushell style when documenting commands (semicolons, etc.).
- If any manual command is required from the user, record it in `appendix.md`.

## Current context (known)
- There is already a module: `modules/system/nvidia-sleep-fix.nix`.
- It supports toggles:
  - `hydenix.system.nvidiaSleepFix.enable`
  - `hydenix.system.nvidiaSleepFix.restartDisplayManagerOnResume`
  - `hydenix.system.nvidiaSleepFix.forceDeepSleep`
- Host config appears to enable:
  - `hydenix.system.nvidiaSleepFix.enable = true;`
  - `hardware.nvidia.open = true;` (RTX 3050 / Ampere)
- Symptom is worse than “black screen but TTY works”: TTY switching doesn’t work.

## Phases

### Phase 0 — Create working memory files (done)
- [x] Create directory `dotfiles/manus/suspend-fix/`
- [ ] Create `notes.md`
- [ ] Create `troubleshooting.md`
- [ ] Create `appendix.md`
- [ ] Create deliverable file (likely `deliverable.md` or `fix.md`) once approach is validated.

### Phase 1 — Identify likely root cause class
Hypotheses (ranked):
1) **NVIDIA resume hard-wedge** (GPU fails to reinit; kernel console also broken; input dead).
2) **Sleep mode mismatch** (`s2idle` unreliable; `deep` works).
3) **Early KMS/console handoff issues** (framebuffer/DRM state; underscore cursor only).
4) **Kernel/firmware regression** (requires kernel param toggles or different driver behavior).
5) Less likely: display-manager/compositor-only issue (because TTY switching fails).

Actions:
- [ ] Capture relevant hardware info to notes (GPU model, laptop model, kernel, BIOS if available).
- [ ] Decide which mitigation set to apply first (least invasive → more invasive).

### Phase 2 — Implement deterministic mitigations in NixOS modules
Target: adjustments that improve resume reliability for NVIDIA + Wayland and prevent hard wedges.

Planned changes (to be validated/reviewed before applying):
- [ ] Add/ensure NVIDIA systemd sleep services are enabled in a supported way:
  - Ensure `hardware.nvidia.powerManagement.enable = true;`
  - Ensure `hardware.nvidia.powerManagement.finegrained = false;` unless PRIME offload is configured
  - Consider `hardware.nvidia.powerManagement.enableS0ix` *only if appropriate* (needs verification).
- [ ] Add `boot.kernelParams` options commonly required for NVIDIA resume reliability, **guarded and documented**, and ideally toggleable:
  - `nvidia-drm.modeset=1` (already present in module)
  - Consider `nvidia.NVreg_PreserveVideoMemoryAllocations=1` (VRAM restore; high impact; needs careful reasoning)
  - Consider `nvidia.NVreg_TemporaryFilePath=/var/tmp` (pairs with PreserveVideoMemoryAllocations; requires writable FS)
- [ ] Add `boot.kernelParams` option to prefer deep sleep when enabled:
  - `mem_sleep_default=deep` (already supported by module option `forceDeepSleep`)
- [ ] Ensure logs survive resume attempts:
  - evaluate whether persistent journal is enabled; if not, consider enabling `services.journald.extraConfig = "Storage=persistent"` (but treat as optional).

Deliverable should include a safe “toggle ladder”:
1. Enable base NVIDIA sleep integration (already enabled)
2. Enable deep sleep (if hardware supports) via `forceDeepSleep`
3. Enable VRAM preservation params (if needed)
4. As last resort: restart DM on resume (workaround; can kill session)

### Phase 3 — Verification workflow (non-destructive)
Because the system becomes unrecoverable when it wedges, define a reproducible test protocol:
- [ ] Run `nix flake check` after config changes.
- [ ] User applies via their standard command.
- [ ] Test suspend/resume multiple times:
  - short suspend (~30s)
  - longer suspend (5–15 min)
- [ ] Capture logs after both success and failure cases.

### Phase 4 — Troubleshooting support artifacts
- [ ] Write a “what to collect” checklist in `troubleshooting.md`:
  - prior boot logs: `journalctl -b -1`
  - current boot resume logs: `journalctl -b`
  - filter patterns: `PM:`, `nvidia`, `NVRM`, `Xid`, `drm`, `systemd-sleep`
  - `cat /sys/power/mem_sleep` output
- [ ] Add a recovery section:
  - If resume wedges, attempt Magic SysRq (if enabled) to sync/reboot safely.
  - If no input works, document that it’s a hard wedge and needs param changes.

### Phase 5 — Final deliverable
- [ ] Create a final doc describing:
  - What changed (Nix options and kernel params)
  - Why it should fix this failure mode
  - How to toggle/rollback
  - How to test
  - What to do if still failing (next escalation steps)

## Decision log (to fill as we go)
- Deep sleep vs s2idle:
  - Decision: (TBD)
  - Evidence: (TBD, from `/sys/power/mem_sleep` + behavior)
- VRAM preservation params:
  - Decision: (TBD)
  - Evidence: (TBD, from NVRM/Xid logs)
- Restart DM on resume:
  - Decision: (TBD)
  - Evidence: (Only if system is alive but session dead)

## Risks / tradeoffs
- Forcing `deep` may increase power draw on some devices or be unsupported.
- VRAM preservation can increase disk usage in `/var/tmp` and may fail if path not writable early enough.
- Restarting display-manager can lose session state; it’s a mitigation, not a root fix.

## Next step
Create `notes.md` and `troubleshooting.md`, then propose the minimal config toggle sequence (starting with `forceDeepSleep`) and document user-side test commands in Nushell style.