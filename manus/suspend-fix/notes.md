# Notes — Suspend/Resume repeating underscore (no TTY switch)

## Symptom snapshot (what you reported)
- On **resume from suspend**, system shows a screen with a **repeating underscore** (looks like a text cursor).
- You **cannot switch to a TTY** (e.g. `Ctrl+Alt+F3` doesn’t work).
- This is materially different from “black screen but OS is alive”, because no TTY strongly suggests an **input/display stack wedge** or **kernel/GPU hang** rather than a compositor-only failure.

## Current repo context (facts from config)
- There is an existing module: `modules/system/nvidia-sleep-fix.nix`
  - Enables NVIDIA DRM modesetting (`hardware.nvidia.modesetting.enable = true`)
  - Enables `hardware.nvidia.powerManagement.enable = true`
  - Adds kernel param `nvidia-drm.modeset=1`
  - Provides optional toggles:
    - `hydenix.system.nvidiaSleepFix.restartDisplayManagerOnResume` (workaround)
    - `hydenix.system.nvidiaSleepFix.forceDeepSleep` (switch suspend mode to S3 “deep”)
- `configuration.nix` already sets:
  - `hydenix.system.nvidiaSleepFix.enable = true;`
  - `hardware.nvidia.open = true;` (explicit override; note in config indicates RTX 3050 / Ampere)
- Niri is enabled:
  - `hydenix.system.niri.enable = true;`
  - This likely means you are on Wayland paths (but exact active session at suspend time is unknown).

## Working hypothesis (ranked)
### H1 — GPU resume hard-wedge (NVIDIA resume path)
Most likely. The “underscore screen” can simply be the last thing scanned out before the GPU or display pipeline wedges. No TTY switch suggests:
- keyboard interrupts not being processed, or
- kernel is stuck in a resume path, or
- GPU/DRM console is wedged so hard it never repaints and input handling is also affected.

### H2 — Suspend mode mismatch: `s2idle` vs `deep`
Common on laptops. If firmware + NVIDIA is unstable on `s2idle`, resume can wedge.
- Switching to deep sleep (S3) often fixes “resume hangs / stuck cursor” class issues.

### H3 — VRAM restoration / modeset ordering issues
On NVIDIA, some systems need explicit VRAM-preservation behavior on suspend so resume can restore modes reliably.

### H4 — Compositor/DM failure (less likely given no TTY)
This is what the `restartDisplayManagerOnResume` workaround targets, but it only helps if the OS is alive and you can at least get to a console/SSH. Your report suggests a deeper failure.

## Notes on “repeating underscore”
- The underscore itself isn’t a meaningful error code; it’s typically just a **console cursor**.
- Seeing only that (and nothing else) usually means the display is stuck very early: either in a console/plymouth handoff, or frozen output.

## Mitigation ladder (ordered from safest to more invasive)
### Step 1: Prefer `deep` suspend (S3) over `s2idle`
- Use the module’s existing knob:
  - `hydenix.system.nvidiaSleepFix.forceDeepSleep = true;`
- Rationale:
  - Low risk, reversible, and frequently resolves “resume hang” on laptops.

### Step 2: Add NVIDIA VRAM preservation kernel params (if deep sleep doesn’t fix)
Likely candidates (to be implemented *as toggleable options* in the module so you can revert cleanly):
- `nvidia.NVreg_PreserveVideoMemoryAllocations=1`
- `nvidia.NVreg_TemporaryFilePath=/var/tmp`

Rationale:
- Helps NVIDIA restore VRAM allocations across suspend/resume.
- Needs a writable temp path; `/var/tmp` is usually safe.

### Step 3: Add a last-resort recovery workaround (only if resume is alive)
- Enable `hydenix.system.nvidiaSleepFix.restartDisplayManagerOnResume = true;`
- Caveat:
  - This can kill your user session state.
  - It won’t help if the kernel is wedged (no TTY, no SSH).

## Data to collect (to confirm which hypothesis is right)
(Keep actual captured outputs in `troubleshooting.md`, not here.)

### Hardware / platform
- GPU: confirm model (config comments say RTX 3050 / Ampere).
- Laptop model + BIOS version (firmware influences s2idle/deep stability).

### Kernel suspend mode capability
- Output of:
  - `cat /sys/power/mem_sleep`
- Expected examples:
  - `[s2idle] deep` (currently using s2idle)
  - `s2idle [deep]` (currently using deep)

### Logs from the boot before the one you’re in now (after a forced power cycle)
- `journalctl -b -1` filtered for:
  - `PM:`
  - `systemd-sleep`
  - `nvidia`, `NVRM`, `Xid`
  - `drm`, `i915`, `amdgpu` (depending on hybrid setup)

## Repo considerations / pitfalls observed
- The module comment says “Wayland (Hyprland)”, but your system is also enabling Niri; ensure fixes are compositor-agnostic (they mostly are).
- `hardware.nvidia.open = true` is set host-wide.
  - If resume remains broken, one diagnostic branch is to try closed modules (`open = false`)—but that’s a bigger policy decision and should be a deliberate switch, not accidental.

## Mistake & correction log (Manus requirement)
- Mistake I want to avoid: treating this as a display-manager issue and enabling the DM restart workaround first.
- Correction: prioritize **suspend mode (`deep`)** and **driver resume/Vram preservation** first, because you can’t even access TTY during the failure, suggesting a lower-level wedge.

## Next TODOs (notes-only)
- Decide and implement: enable `forceDeepSleep` first (minimal change).
- If still failing: extend `nvidia-sleep-fix.nix` with a new toggle for NVreg VRAM preservation params.
- Prepare a clear user test protocol (short suspend + longer suspend) and log capture steps in `troubleshooting.md`.