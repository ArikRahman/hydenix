# Suspend/Sleep Resume → Black Screen (Hydenix / NixOS)  
Diagnostic + Remediation Guide

This guide is for the symptom: you suspend/sleep the machine, come back later, and resume either shows a **black screen**, **frozen display**, **no backlight**, or a **stuck lock screen**. Often the machine is actually running (fans/keyboard lights/responds to ping), but graphics/display doesn’t recover.

The most common causes on NixOS are:
- **GPU driver resume bugs** (NVIDIA most often; also AMD/iGPU in some combos)
- **Wayland compositor resume issues** (Hyprland/Sway/KDE Wayland)
- **Kernel sleep state / firmware issues** (S3 vs s2idle, ACPI quirks)
- **DPMS / display link retraining issues** (esp. external monitors / docks)
- **systemd-logind / lid switch / display manager edge cases**

This is written as a structured workflow so you can quickly narrow it down and then apply the right fix.

---

## 0) What to record (so you don’t chase ghosts)

Before changing anything, collect these facts:

### Hardware + session
- GPU: Intel? AMD? NVIDIA? Hybrid (Intel+NVIDIA)?
- Laptop or desktop? Any external monitors/dock?
- Session type: Wayland (Hyprland/Sway/KDE) or X11?
- Display manager: SDDM/GDM/none (tty start)?
- How do you suspend: lid close, power menu, `systemctl suspend`?

### Repro details
- Does it fail only after “a while” (e.g. >30 min)?
- Does it fail only on AC/battery?
- Does it fail only with external monitor attached?

Write these down in `dotfiles/manus/sleep-black-screen/notes.md` as you go.

---

## 1) First triage: is the system alive or hard-hung?

When you return to a black screen:

1. **Try switching TTYs:** `Ctrl+Alt+F2` (or F3/F4).
   - If you get a login prompt, the kernel is alive; it’s probably **graphics/compositor/DM**.
   - If TTY is also dead and caps lock doesn’t toggle, it may be deeper (kernel/firmware).

2. **Try SSH in** (if enabled) from another machine.
   - If you can SSH, you can safely collect logs and restart services without rebooting.
   - If you can’t, you’re forced into reboot testing and BIOS/firmware avenues sooner.

3. **Try “blind” reboot as last resort:**
   - Prefer Magic SysRq REISUB if enabled.
   - Otherwise hold power.

Outcome:
- **Alive:** focus on GPU + display stack.
- **Dead:** focus on sleep state + kernel + firmware.

---

## 2) Get the right logs (most important step)

You want logs from the *previous boot* (the one that failed resume).

### High-value log queries
Run after reboot:
- `journalctl -b -1 -p err..alert`
- `journalctl -b -1 | grep -iE "suspend|resume|sleep|wakeup|drm|gpu|amdgpu|i915|nvidia|nouveau|gdm|sddm|hypr|sway|kwin|wayland"`
- `dmesg -T | grep -iE "PM: suspend|PM: resume|freeze|wakeup|ACPI|drm|amdgpu|i915|nvidia"`

What you’re looking for:
- `PM: suspend entry` and `PM: resume from` timestamps (did resume actually occur?)
- DRM errors: modeset failures, link training, GPU reset failures
- NVIDIA-specific messages about preserving video memory or failing to reinit
- systemd-logind messages around lid switch and session

**Manus note:** copy the most relevant snippets into `notes.md` so you can compare between iterations.

---

## 3) Identify which bucket you’re in

### A) NVIDIA (proprietary driver) bucket
Strong indicators:
- You use `nvidia` driver (not nouveau).
- Logs show `NVRM` lines, or “failed to allocate”, “GPU has fallen off the bus”, etc.
- Resume works sometimes, but fails more with external monitors or long sleeps.

Likely fixes:
- Enable NVIDIA power management features (video memory preservation).
- Ensure correct kernel params for modeset.
- Consider toggling Wayland vs X11 depending on compositor and driver version.

### B) AMDGPU / Intel i915 bucket
Indicators:
- Logs show `amdgpu` ring hang, GPU reset; or `i915` GuC/HuC errors; or DRM link training failures.

Likely fixes:
- Kernel parameters (e.g. enable/disable DC on AMD, tweak i915 options).
- Use a newer kernel or firmware.
- Change sleep state from s2idle to deep (or vice versa).

### C) Wayland compositor / DM bucket
Indicators:
- Kernel resumes fine, but compositor is frozen/black.
- TTY works.
- Restarting the compositor or display manager recovers without reboot.

Likely fixes:
- Resume hooks to reinitialize monitors (DPMS reset).
- Switch compositor backend settings.
- For SDDM/GDM: adjust Wayland usage.

### D) Sleep-state / firmware bucket (system appears hung)
Indicators:
- Even TTY or SSH is dead.
- Logs show incomplete suspend/resume sequence.
- Often affected by BIOS quirks and `mem_sleep` mode.

Likely fixes:
- Force sleep state: `deep` vs `s2idle`.
- BIOS update; disable problematic devices waking the system.
- Update kernel + `linux-firmware`.

---

## 4) Remediation options (in priority order)

### 4.1 Update: kernel + firmware first
Resume bugs are often fixed upstream.

In Hydenix/NixOS terms, that typically means:
- Use a newer kernel package (e.g. latest stable)
- Ensure `linux-firmware` is current
- Rebuild and retest

If you’re already on a recent kernel, continue below.

---

### 4.2 Force sleep state: `deep` vs `s2idle`
Linux laptops may default to `s2idle` (modern standby). Some machines only behave on `deep` (S3), others the opposite.

**How to check current mode:**
- Inspect `/sys/power/mem_sleep` (you’ll see something like: `s2idle [deep]` or `[s2idle] deep`)

**Try forcing deep:**
- Add kernel param: `mem_sleep_default=deep`

**Or forcing s2idle:**
- Add: `mem_sleep_default=s2idle`

Retest after each change.

Why this works:
- Some GPU/firmware combinations fail to restore reliably from one mode.

---

### 4.3 NVIDIA: enable preservation + modeset
If you’re on proprietary NVIDIA, these are common “must haves”:

- Ensure **modesetting** is enabled (`nvidia-drm.modeset=1`).
- Enable NVIDIA suspend/resume integration so VRAM is preserved (where supported).

On NixOS this usually corresponds to enabling NVIDIA power management options and the systemd sleep hooks that come with the driver integration.

Retest scenarios:
- Suspend for 1 minute (quick)
- Suspend for 30–60 minutes (your failure window)
- Suspend with/without external monitor

---

### 4.4 Compositor/Wayland-friendly mitigations (when TTY works)
If the system is alive but the display is black, the fastest workaround is: restart the display stack.

Examples of recovery actions (conceptual, pick what matches your setup):
- Restart display manager (GDM/SDDM) from TTY:
  - `systemctl restart display-manager`
- If you start your compositor from `.profile` or similar, log out/in and restart session.
- For external monitor black screen:
  - Trigger a monitor re-detect (compositor-specific)
  - Toggle DPMS off/on

If this fixes it reliably, you’re likely in bucket **C** and should focus on compositor + GPU driver interactions.

---

### 4.5 External monitors / docks
Resume black screen frequently involves DisplayPort link training after sleep, especially with:
- USB-C docks
- DP MST hubs
- KVM switches

Mitigations:
- Test resume with **all external displays unplugged**.
- If that fixes it, you can:
  - Add a resume hook to reinitialize displays (compositor-specific)
  - Prefer HDMI over DP (sometimes)
  - Update dock firmware if applicable

---

### 4.6 Hybrid graphics (Intel+NVIDIA / PRIME)
Hybrid setups add another failure mode: the “wrong GPU” becomes the active display provider after resume.

Mitigations:
- Confirm whether you’re using PRIME offload vs full NVIDIA mode.
- Try:
  - Full iGPU mode for testing (disable dGPU usage)
  - Full dGPU mode for testing (force NVIDIA)
- Whichever is stable, you can then refine from there.

---

## 5) A minimal “test matrix” (so you converge quickly)

Run tests in this order and write results in `notes.md`:

1. **Baseline**: suspend 1 minute, internal display only.
2. Suspend 30 minutes, internal only.
3. Suspend 30 minutes, external display attached.
4. Alternate sleep state (`deep` vs `s2idle`) and rerun 1–3.
5. If NVIDIA: enable/confirm modeset + power management and rerun.

You’re trying to find the smallest change that flips it from “fails” to “works” and the smallest condition that reproduces the failure.

---

## 6) Where to implement fixes in Hydenix

Hydenix is flake-based and prefers putting config in modules.

General rule:
- System-level knobs (kernel params, drivers, systemd sleep settings) belong in `modules/system/...` or the main `configuration.nix`.
- User session/compositor behaviors (Hyprland/Sway, monitor re-detect scripts) belong in `modules/hm/...`.

If you tell me:
- GPU type (and whether hybrid),
- compositor (Hyprland/Sway/KDE/GNOME) and Wayland vs X11,
- whether TTY/SSH works during the black screen,
- and paste the relevant `journalctl -b -1` snippets around suspend/resume and DRM,

…I can propose the exact NixOS module changes you should apply (kernel params, NVIDIA settings, or compositor resume hooks) in a way that fits your repo layout.

---

## 7) Common “quick answers” mapped to symptoms

### “Black screen but I can switch to TTY”
Usually graphics stack/compositor/DM. Focus on:
- GPU driver resume behavior
- display-manager restart recovery
- Wayland vs X11 switching test
- external monitor link training

### “Black screen, no TTY, no SSH”
Usually sleep state / firmware / kernel hard hang. Focus on:
- `mem_sleep_default=deep` vs `s2idle`
- BIOS + firmware updates
- kernel updates

### “Only fails with external monitors”
Usually DP link training/dock. Focus on:
- resume hook to reinit outputs
- dock/monitor firmware
- swapping DP <-> HDMI

### “Only fails on NVIDIA”
Usually NVIDIA PM integration missing or a driver regression. Focus on:
- modeset + power management + preserved memory
- driver version changes (newer or sometimes older LTS)

---

## 8) Next step (what you should send back)
Reply with:
1) GPU(s) + laptop model (if you know it)  
2) Wayland vs X11 + compositor/DM  
3) Does TTY work when black screen happens?  
4) The most relevant lines from:
- `journalctl -b -1 | grep -iE "PM: suspend|PM: resume|drm|amdgpu|i915|nvidia|NVRM|wayland|sddm|gdm|hypr|sway|kwin"`

From that, I’ll tell you which bucket you’re in and the smallest Nix config change to try first.