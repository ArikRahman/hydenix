# Notes — Suspend/Resume issues (underscore / stop-job hang)

## Symptom snapshot (updated)
- The failure is **context-dependent**:
  - From the **login screen**, you can **suspend and hibernate easily**.
  - From the **active desktop session**, suspend/hibernate can appear to **hang for a long time** on a **systemd “A stop job is running …”** message.
- On **hibernate**, you can sometimes hit `Ctrl+Alt+F3` **briefly** (suggesting the OS is not fully dead, but shutdown/sleep is blocked on a unit stop).
- You previously described a **repeating underscore** screen; that may be the last console state while the system is waiting on a stop job (not necessarily a pure GPU hard-wedge).

Implication:
- This shifts the primary hypothesis away from “GPU resume hard-wedge” and toward **a slow/hung service stop on suspend/hibernate when user session is active** (often user services, mounts, network, GPU helper units, or apps holding resources).

## Current repo context (facts from config)
- There is an existing module: `modules/system/nvidia-sleep-fix.nix`
  - Enables NVIDIA DRM modesetting (`hardware.nvidia.modesetting.enable = true`)
  - Enables `hardware.nvidia.powerManagement.enable = true`
  - Adds kernel param `nvidia-drm.modeset=1`
  - Provides optional toggles:
    - `hydenix.system.nvidiaSleepFix.restartDisplayManagerOnResume` (workaround; only helps if the system resumes but graphics is broken)
    - `hydenix.system.nvidiaSleepFix.forceDeepSleep` (switch suspend mode to S3 “deep”)
    - `hydenix.system.nvidiaSleepFix.enableVramPreservation` (optional; adds NVreg VRAM-preservation kernel params)
- `configuration.nix` already sets:
  - `hydenix.system.nvidiaSleepFix.enable = true;`
  - `hardware.nvidia.open = true;` (explicit override; note in config indicates RTX 3050 / Ampere)
  - `hydenix.system.nvidiaSleepFix.forceDeepSleep = true;` (now enabled to prefer S3 deep)
- Niri is enabled:
  - `hydenix.system.niri.enable = true;`
  - This suggests Wayland is in play, but your symptom points more to **shutdown/sleep orchestration** (stop jobs) than compositor-only resume issues.

## Working hypothesis (re-ranked based on “stop job” hang)
### H1 — A service is timing out/hanging during suspend/hibernate when the desktop session is active
Most likely now, because:
- login-screen suspend/hibernate works (minimal user services/apps running),
- the active desktop triggers “A stop job is running …”, which is systemd waiting for a unit to stop.

Common culprits:
- user services (Home Manager services, portals, polkit agents, clipboard daemons, notification daemons)
- network services with long stop timeouts
- mount units / automounts / encrypted volumes
- Bluetooth/audio stacks
- GPU helper units (less common than apps/services, but still possible)

### H2 — Suspend mode mismatch (`s2idle` vs `deep`)
Still plausible. Deep sleep can reduce the complexity of the suspend path on some laptops, but it won’t fix a unit that is simply refusing to stop.

### H3 — NVIDIA resume wedge / modeset restore problems
Still possible, but the presence of a **systemd stop job** message suggests the system is actively orchestrating shutdown/sleep and waiting, not instantly wedged.

### H4 — Compositor/DM failure on resume
Least likely for the “stop job” scenario; that’s more a resume-time symptom, whereas “stop job is running” is a suspend/hibernate-time symptom.

## Notes on “repeating underscore”
- The underscore itself isn’t a meaningful error code; it’s typically just a **console cursor**.
- Seeing only that (and nothing else) usually means the display is stuck very early: either in a console/plymouth handoff, or frozen output.

## Mitigation ladder (updated for “stop job is running …”)
### Step 1: Identify the exact “stop job” unit (don’t guess)
- The “A stop job is running …” line includes the **unit name** (sometimes truncated).
- Once you know the unit, you can:
  - reduce its stop timeout, or
  - change ordering so it stops earlier/later, or
  - fix the underlying resource it’s waiting on.

> This is the main missing piece right now: which unit is systemd waiting for.

### Step 2: Only then apply targeted systemd overrides (declaratively)
Examples of what “targeted” might mean (not applied automatically here):
- set a shorter `TimeoutStopSec=` for the offending service
- add `KillMode=` / `SendSIGKILL=` if it is safe for that service
- fix mount dependencies (e.g., ensure user services don’t block on a flaky automount)

### Step 3: Keep “deep sleep” as a parallel lever
- `hydenix.system.nvidiaSleepFix.forceDeepSleep = true;` is already enabled in your config.
- It may help overall reliability, but it’s not a substitute for fixing a stop-job hang.

### Step 4: NVIDIA VRAM preservation (only if the issue is actually resume-time)
- Use:
  - `hydenix.system.nvidiaSleepFix.enableVramPreservation = true;`
- This is for “resume is broken,” not “systemd can’t get into sleep.”

### Step 5: Restart display-manager on resume (workaround)
- `hydenix.system.nvidiaSleepFix.restartDisplayManagerOnResume = true;`
- Only helpful if the machine resumes but graphics is stuck.

## Data to collect (updated: focus on identifying the stop-job culprit)
(Keep actual captured outputs in `troubleshooting.md`, not here.)

### A) The exact unit shown in the “stop job” message
- When it hangs, note the unit name from the on-screen line (even if truncated).
- If you can get to a TTY briefly, run log capture after reboot.

### B) Logs that show which unit blocked suspend/hibernate
Capture and filter (record outputs in `troubleshooting.md`):
- `journalctl -b -1` for:
  - `systemd[1]: Stopping`
  - `A stop job is running`
  - `systemd-sleep`
  - `sleep.target`, `suspend.target`, `hibernate.target`
  - plus GPU keywords (`nvidia`, `NVRM`, `Xid`, `drm`) in case it’s actually resume-time

### C) Kernel suspend mode capability (still useful)
- `cat /sys/power/mem_sleep` (confirm whether `[deep]` is active after enabling the kernel param)

## Repo considerations / pitfalls observed (updated)
- The module comment says “Wayland (Hyprland)”, but your system is also enabling Niri; the low-level NVIDIA sleep plumbing is compositor-agnostic, but:
  - “stop job is running …” is usually **not** compositor-specific; it’s about **systemd unit stop ordering/timeouts**.
- `hardware.nvidia.open = true` is set host-wide.
  - If the final diagnosis is truly NVIDIA-driver-related, one diagnostic branch is to try closed modules (`open = false`)—but treat that as a deliberate experiment after we confirm it’s not simply a stuck unit.

## Mistake & correction log (Manus requirement)
- Mistake (earlier assumption): I treated the underscore/no-TTY report as a pure GPU resume hard-wedge and prioritized resume-time mitigations first.
- Correction (based on your new evidence): The key failure during an active desktop is that suspend/hibernate **waits forever on a stop job**. That points to identifying the blocking unit and fixing its stop behavior (timeouts/order/dependencies) as the primary path. Deep sleep and NVIDIA resume tweaks remain secondary levers.

## Next TODOs (notes-only)
- Decide and implement: enable `forceDeepSleep` first (minimal change).
- If still failing: extend `nvidia-sleep-fix.nix` with a new toggle for NVreg VRAM preservation params.
- Prepare a clear user test protocol (short suspend + longer suspend) and log capture steps in `troubleshooting.md`.