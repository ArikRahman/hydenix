# Troubleshooting — Suspend/Resume failure (repeating underscore, no TTY switch)
#
# Purpose
# - This file is the *logbook* for suspend/resume debugging.
# - Keep raw command output here so it survives context resets and can be compared across attempts.
#
# Symptom (reported)
# - Resume shows a screen with a repeating underscore cursor.
# - Ctrl+Alt+F* does not switch to a TTY.
# - This suggests a deeper resume wedge (kernel/DRM/GPU) rather than just a compositor crash.

---

## 0) Safety / recovery notes (read before testing)
If resume wedges and your input appears dead:

- Try waiting 60–90 seconds: some systems take a long time to reinitialize GPU on resume.
- If you can, try Magic SysRq (if enabled by your kernel settings):
  - REISUB sequence is a common safe reboot procedure.
  - If SysRq is disabled in your system, note it below.
- If nothing works, you may be forced to hold the power button. When that happens:
  - The most useful logs are in the *previous boot* (`journalctl -b -1`), so capture those right after you boot back up.

Record every hard power cycle below; it helps correlate “what changed” with “what failed”.

---

## 1) Environment snapshot (fill once, update if changed)

### Hardware
- Machine model:
- BIOS/UEFI version:
- GPU(s): (e.g., NVIDIA RTX 3050 + Intel iGPU)
- Internal display only / external monitor / dock:
- Kernel version (from `uname -a`):

### Session info (before suspending)
- Desktop/compositor at time of suspend: (Hyprland / Niri / Plasma / other)
- Display manager: (SDDM / GDM / greetd / other)
- Wayland or X11:

### NixOS config flags relevant to suspend
- `hydenix.system.nvidiaSleepFix.enable`:
- `hydenix.system.nvidiaSleepFix.forceDeepSleep`:
- `hydenix.system.nvidiaSleepFix.restartDisplayManagerOnResume`:
- `hardware.nvidia.open`:

---

## 2) Repro protocol (use the same steps each time)

### Short suspend test (baseline)
1. Save work and close GPU-heavy apps.
2. Suspend.
3. Wait ~30 seconds.
4. Resume.
5. Outcome: (Success / Fail)
6. If fail: did keyboard LEDs toggle? did screen backlight change? fans spin?

### Medium suspend test
1. Suspend.
2. Wait 5–15 minutes.
3. Resume.
4. Outcome: (Success / Fail)

### Notes / variables
- Power state: (on battery / plugged in)
- Lid closed? (yes/no)
- External monitor connected? (yes/no)
- Bluetooth devices connected? (yes/no)

---

## 3) Data collection commands (capture outputs verbatim)

> Notes:
> - You’re using Nushell; commands below are written as one-liners you can paste.
> - Run these **after a successful resume**, or **after rebooting from a failed resume** (use `-b -1`).

### 3.1 Suspend mode capability and current selection
```/dev/null/nu#L1-6
# Shows which suspend modes are available and which is active (brackets).
cat /sys/power/mem_sleep;
```

Paste output here:
- Output:
  - 

### 3.2 Previous boot logs (most important after a hard power cycle)
```/dev/null/nu#L1-8
# Capture previous boot logs to a file for later review.
# Note: adjust the output path if you prefer a different location.
journalctl -b -1 --no-pager | save -f manus/suspend-fix/logs/journal-b-1.txt;
```

Paste a short summary here:
- Did you hard power cycle? (yes/no)
- File saved: `manus/suspend-fix/logs/journal-b-1.txt`
- Quick notes:

### 3.3 Filtered suspend/resume-related slice
```/dev/null/nu#L1-12
# Filter for common suspend/resume and GPU keywords.
journalctl -b -1 --no-pager
| lines
| where {|l| $l =~ 'PM:|systemd-sleep|suspend|resume|nvidia|NVRM|Xid|drm|i915|amdgpu|ACPI|s2idle|S3' }
| save -f manus/suspend-fix/logs/journal-b-1-filtered.txt;
```

Paste highlights here (e.g., first error, first warning, last lines before crash):
- Highlights:
  - 

### 3.4 systemd sleep service status (after a *successful* resume)
```/dev/null/nu#L1-12
# Look for sleep hooks and failures in this boot.
journalctl -b --no-pager
| lines
| where {|l| $l =~ 'systemd-sleep|sleep.target|suspend.target|nvidia-suspend|nvidia-resume|nvidia-hibernate' }
| save -f manus/suspend-fix/logs/journal-b-sleep.txt;
```

Paste highlights:
- Highlights:
  - 

### 3.5 Kernel ring buffer (if available after reboot)
```/dev/null/nu#L1-7
# Kernel messages can contain NVIDIA Xid or DRM errors around resume.
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

### A) No TTY switch, no SSH, keyboard appears dead
Likely: kernel/firmware/GPU resume wedge.
Next levers (least → more invasive):
- Prefer `deep` suspend over `s2idle` (`mem_sleep_default=deep`).
- NVIDIA VRAM preservation kernel params.
- Consider trying NVIDIA open vs closed kernel modules (policy choice; document carefully).

### B) TTY works but graphics is black / frozen
Likely: compositor/DM didn’t recover.
Next levers:
- DM restart-on-resume workaround.
- Wayland compositor-specific tweaks.
- Look for `nvidia` or `drm` errors but system itself is alive.

### C) Resume works sometimes but not reliably
Likely: timing/race/firmware interaction with s2idle, external monitors, docks, or PRIME.
Next levers:
- Test variables one at a time: external monitor, lid state, power source.
- Prefer `deep` if available.
- Capture consistent logs across both success and failure.

---

## 6) Meta: What I got wrong & how I corrected it (Manus requirement)
- Mistake to avoid: assuming this is “just a compositor black screen” and jumping straight to restarting the display manager.
- Correction: because you cannot switch TTYs, start with mitigations that address **suspend mode** and **GPU resume hard-wedges** first; only use DM restart as a fallback when the OS is clearly alive.
