# Troubleshooting — Suspend/Hibernate hangs (“A stop job is running …”) from active desktop
#
# Purpose
# - This file is the *logbook* for suspend/hibernate debugging.
# - Keep raw command output here so it survives context resets and can be compared across attempts.
#
# Symptom (updated)
# - Suspending/hibernating from the **login screen** works reliably.
# - Suspending/hibernating from the **active desktop session** can hang for a long time on:
#   “A stop job is running …”
# - You may briefly be able to switch to a TTY (e.g. Ctrl+Alt+F3), which strongly suggests
#   the OS is alive and systemd is **waiting for a unit to stop**.
#
# Primary goal of this guide
# - Identify the exact **blocking systemd unit** that is causing the stop-job countdown.
# - Apply a targeted, declarative fix (timeouts/order/dependencies) once the unit is known.

---

## 0) Safety / recovery notes (read before testing)
If suspend/hibernate appears stuck on a stop job:

- Wait long enough to confirm it’s actually stuck (e.g. 1–3 minutes).
- Photograph or write down the **exact unit name** shown in the “A stop job is running …” line.
  - Even if it’s truncated, partial names help.
- If you can briefly reach a TTY, that’s a good sign: the system is alive and systemd is waiting.
- If you must hard power off:
  - The most useful evidence is the *previous boot* journal (`journalctl -b -1`), so capture it immediately after booting back up.

Record every hard power cycle below; it helps correlate “what changed” with “what failed”.

---

## 1) Environment snapshot (fill once, update if changed)

### Hardware
- Machine model:
- BIOS/UEFI version:
- GPU(s): (e.g., NVIDIA RTX 3050 + Intel iGPU)
- Internal display only / external monitor / dock:
- Kernel version (from `uname -a`):

### Session info (before suspending/hibernating)
- Desktop/compositor at time of action: (Hyprland / Niri / Plasma / other)
- Display manager: (SDDM / GDM / greetd / other)
- Wayland or X11:
- Were any “heavy” apps running? (Steam, browsers w/ video, GPU apps, Docker, VM, etc.)

### NixOS config flags relevant to sleep
- `hydenix.system.nvidiaSleepFix.enable`:
- `hydenix.system.nvidiaSleepFix.forceDeepSleep`:
- `hydenix.system.nvidiaSleepFix.enableVramPreservation`:
- `hydenix.system.nvidiaSleepFix.restartDisplayManagerOnResume`:
- `hardware.nvidia.open`:

---

## 2) Repro protocol (use the same steps each time)

### Baseline: suspend from login screen (control)
1. Log out to the display manager (login screen).
2. Suspend.
3. Wait ~30 seconds.
4. Resume.
5. Outcome: (Success / Fail)

### Main repro: suspend from active desktop (problem case)
1. Log in and reproduce your normal “working desktop” state.
2. Suspend.
3. If you see “A stop job is running …”:
   - record the unit name shown on-screen (write it below in section 4)
   - wait 1–3 minutes to see whether it completes or times out
4. Outcome: (Success / Fail / Hangs on stop job)

### Optional: hibernate from active desktop (problem case)
1. Hibernate.
2. If you see a stop-job line, record the unit name.
3. Outcome: (Success / Fail / Hangs on stop job)

### Notes / variables (keep controlled)
- Power state: (on battery / plugged in)
- Lid closed? (yes/no)
- External monitor connected? (yes/no)
- Bluetooth devices connected? (yes/no)
- Network state: (wifi/ethernet/vpn)

---

## 3) Data collection commands (capture outputs verbatim)

> Notes:
> - You’re using Nushell; commands below are written as one-liners you can paste.
> - The most important thing now is to capture evidence of **which unit blocked sleep**.

### 3.1 Suspend mode capability and current selection (still useful)
```/dev/null/nu#L1-6
# Shows which suspend modes are available and which is active (brackets).
cat /sys/power/mem_sleep;
```

Paste output here:
- Output:
  - 

### 3.2 Capture previous boot logs (most important after a hard power cycle)
```/dev/null/nu#L1-8
# Capture previous boot logs to a file for later review.
journalctl -b -1 --no-pager | save -f manus/suspend-fix/logs/journal-b-1.txt;
```

Paste a short summary here:
- Did you hard power cycle? (yes/no)
- File saved: `manus/suspend-fix/logs/journal-b-1.txt`
- Quick notes:

### 3.3 Filter specifically for stop-job and unit-stop blockers (key slice)
```/dev/null/nu#L1-16
# Filter for stop-job countdowns and the unit stop/start lines around them.
journalctl -b -1 --no-pager
| lines
| where {|l|
    $l =~ 'A stop job is running' or
    $l =~ 'Stopped ' or
    $l =~ 'Stopping ' or
    $l =~ 'Timed out waiting for' or
    $l =~ 'Failed to stop' or
    $l =~ 'Reached target Sleep' or
    $l =~ 'suspend.target|hibernate.target|sleep.target|systemd-sleep'
  }
| save -f manus/suspend-fix/logs/journal-b-1-stopjob.txt;
```

Paste highlights here (especially the exact unit names mentioned):
- Highlights:
  -

### 3.4 Identify long-running units during a stuck attempt (only if you can reach a TTY)
```/dev/null/nu#L1-6
# Shows current jobs and can reveal what systemd is waiting on (if still responsive).
systemctl list-jobs;
```

Paste output here:
- Output:
  -

### 3.5 Kernel ring buffer (keep for NVIDIA/DRM context)
```/dev/null/nu#L1-7
# Kernel messages can contain NVIDIA Xid or DRM errors (secondary signal here).
dmesg | save -f manus/suspend-fix/logs/dmesg-current.txt;
```

Paste highlights:
- Highlights:
  -

---

## 4) Attempt log (append one block per change/test)

### Attempt YYYY-MM-DD HH:MM (local)
**Change(s) made**
- (example) Enabled deep sleep: `hydenix.system.nvidiaSleepFix.forceDeepSleep = true;`
- (example) Added NVreg VRAM preservation params

**Applied to system**
- `nix flake check` result: (pass/fail)
- Rebuild command you ran: (user runs this; record exact command)
- Generation/date:

**Test(s)**
- Short suspend: (pass/fail) notes:
- Medium suspend: (pass/fail) notes:

**Outcome**
- (What happened on resume? underscore? black screen? fans? keyboard dead?)

**Logs captured**
- `journal-b-1.txt` updated? (yes/no)
- `journal-b-1-filtered.txt` updated? (yes/no)
- Notable lines:
  - 

---

## 5) Triage guide (how to interpret common outcomes)

### A) Hangs at “A stop job is running …” only from active desktop
Likely: a systemd unit (often user/session-adjacent) is slow/hung when stopping.
Next levers (in order):
1) Identify the unit name from the on-screen stop-job line and from `journal-b-1-stopjob.txt`.
2) Apply a **targeted** fix for that unit:
   - reduce `TimeoutStopSec=`
   - fix ordering/dependencies
   - stop the real underlying blocker (mounts, network, portals, user services, etc.)
3) Re-test from active desktop.

### B) Suspend/hibernate completes but resume graphics is black/frozen
Likely: GPU/DM/compositor resume path.
Next levers:
- NVIDIA resume mitigations (VRAM preservation toggle).
- As workaround only: restart `display-manager.service` after resume.

### C) Can’t switch TTY / input appears dead
Likely: kernel/firmware/GPU wedge.
Next levers:
- Prefer `deep` suspend if available.
- NVIDIA VRAM preservation kernel params.
- Consider trying NVIDIA open vs closed kernel modules (policy choice; document carefully).

### D) Works from login screen but flaky from desktop
Likely: interaction with running apps/services.
Next levers:
- Re-test with one variable at a time (external monitor, VPN, Steam, browsers/video, etc.)
- Keep attempt logs consistent and capture stop-job evidence each time.

---

## 6) Meta: What I got wrong & how I corrected it (Manus requirement)
- Mistake to avoid: assuming this is “just a compositor black screen” and jumping straight to restarting the display manager.
- Correction: because you cannot switch TTYs, start with mitigations that address **suspend mode** and **GPU resume hard-wedges** first; only use DM restart as a fallback when the OS is clearly alive.
