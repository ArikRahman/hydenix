# Notes — Suspend/Sleep Resume → Black Screen (NixOS / Hydenix)

## Confirmed environment (from user)
- GPU: NVIDIA
- Session: Wayland
- Compositor: Hyprland
- Symptom: resume → black screen; interactive commands “don’t work” on the graphical session
- Important clue: `Ctrl+Alt+F3` works (TTY is reachable)
  - This strongly suggests the system is alive and the failure is **graphics stack / compositor / NVIDIA resume**, not a full kernel hang.

## What you’re seeing
After suspend or sleep (sometimes only after a longer time), the laptop/desktop “wakes” but:
- display stays black (maybe backlight on/off),
- keyboard/mouse may or may not respond,
- you might still be able to SSH in, or audio continues, etc.

This is typically a **resume path failure** in one of these layers:
1. **GPU driver / modeset** (most common): the graphics stack fails to reinitialize the display.
2. **Display manager / compositor**: Wayland/Xorg session doesn’t recover, leaving a black screen.
3. **Kernel power management**: the system resumes partially; device never comes back.
4. **Firmware/BIOS/ACPI quirks**: certain sleep states (S3 vs s2idle) are unreliable on the machine.

---

## High-probability causes by hardware / stack

### NVIDIA (proprietary driver)
Common symptom: black screen after resume; system may still be alive.
Typical mitigations involve:
- enabling NVIDIA suspend/resume services (`nvidia-suspend`, `nvidia-resume`, `nvidia-hibernate`)
- ensuring KMS settings are correct (often `nvidia-drm.modeset=1`)
- choosing Wayland vs Xorg carefully (Wayland can be fine on newer drivers; Xorg sometimes more stable depending on setup)
- handling VRAM preservation settings (varies by driver generation)

### AMD (amdgpu)
Usually OK, but black screens happen with:
- certain kernels/firmware combos
- `s2idle` vs `deep` sleep issues
Mitigations:
- try different sleep state (deep vs s2idle)
- update firmware/microcode
- sometimes tweak `amdgpu` kernel params (only if logs point there)

### Intel (i915)
Less common nowadays, but still possible:
- panel self refresh / DC states can be problematic
Mitigations:
- try different kernel
- try targeted i915 params only if logs clearly indicate

### Wayland compositor (Hyprland/Sway/KDE/GNOME)
Sometimes the GPU resumes but the compositor fails to repaint / rebind outputs.
Mitigations:
- compositor-specific resume hooks
- switching login session type for testing (Wayland ↔ Xorg)
- restarting compositor (if you can switch to TTY)

---

## What I need to know (fill these in)
These answers determine the fastest fix path.

### System basics
- **GPU vendor** (NVIDIA / AMD / Intel):  
- **Laptop or desktop** (dGPU only? hybrid iGPU+dGPU?):  
- **Kernel version** (`uname -r`):  
- **Display manager** (GDM/SDDM/LightDM/tydm/etc):  
- **Session** (Wayland or Xorg):  
- **Compositor/DE** (Hyprland/KDE/GNOME/Sway/etc):  

### Behavior clues
- When it black-screens, is the system reachable via **SSH** or does CapsLock toggle?
- Does switching to a **TTY** work (Ctrl+Alt+F2/F3)?
- Is it “black but backlight on” vs “monitor totally off”?
- Does it happen only on **long sleeps** (minutes-hours) vs immediately?

---

## Logging / evidence to capture (important)
Resume bugs are almost always solved by reading the resume logs.

### Primary logs
- `journalctl -b -1` (previous boot) if it hard-resets
- `journalctl -b` around the suspend/resume time if it doesn’t reboot
- `systemd-logind` messages about sleep
- kernel lines containing: `PM:`, `suspend`, `resume`, `drm`, `nvidia`, `amdgpu`, `i915`

### For GPU-specific hints, look for terms:
- NVIDIA: `NVRM`, `Xid`, `nvidia-modeset`, `nv_drm`, `GPU has fallen off the bus`
- AMD: `amdgpu`, `ring`, `GPU reset`, `failed to resume`
- Intel: `i915`, `GPU HANG`, `reset`, `DC state`

### “Was the machine alive?”
If SSH works during black screen, it’s almost certainly the **graphics stack** (not full system hang).

---

## Known “first fixes” (safe experiments)
These are common “narrow down the culprit” steps.

1. **Try a different sleep state**
   - Some machines fail with `s2idle` but succeed with `deep` (S3) or vice versa.
   - NixOS can force/steer this via kernel params or systemd sleep config.

2. **Try switching session type**
   - If you’re on Wayland, test Xorg (or the opposite).
   - Goal: determine if the issue is compositor/Wayland-specific.

3. **If NVIDIA: ensure suspend/resume integration is enabled**
   - NixOS has standard options/services for this; it often fixes black screen resume.

4. **Kernel regression check**
   - If this started “recently”, try pinning or testing a different kernel series.

5. **Disable “fast startup” equivalents / hybrid sleep**
   - Sometimes hybrid-sleep / hibernate paths cause issues.

---

## NixOS / Hydenix-specific investigation notes
Hydenix is a flake-based NixOS config with modules:
- prefer changes in `modules/system/` or appropriate HM modules
- if we add kernel params / services, comment why (resume bug workaround)
- avoid deleting: comment out previous options and note why replaced

Likely places to implement fixes:
- a system module that sets:
  - `boot.kernelParams`
  - `services.logind.*` (sleep behavior)
  - GPU driver options (NVIDIA/AMD/Intel)
  - systemd sleep hooks (if needed)

---

## Next actions (to do)
1. Collect the filled-in “System basics” above, plus these NVIDIA/Hyprland specifics:
   - NVIDIA driver type: proprietary (`nvidia`) vs `nouveau`
   - Display manager: SDDM/GDM/greetd/etc (or Hyprland started another way)
   - External monitors/dock: yes/no (and connection type: DP/HDMI/USB-C)

2. During the next black-screen resume, use the fact that TTY works to test recovery actions:
   - On TTY, try: `systemctl restart display-manager`
     - If this fixes it, the resume failure is likely “session stack stuck” (DM/Hyprland/Wayland path).
   - If you don’t use a display manager, note how you start Hyprland and we’ll choose the right restart target.

3. Capture logs for the failed resume (previous boot if you had to power-cycle):
   - `journalctl -b -1 -p err..alert`
   - `journalctl -b -1 | grep -iE "PM: suspend|PM: resume|drm|nvidia|NVRM|nv_drm|nvidia-modeset|xid|hypr|wayland|sddm|gdm|greetd"`
   Save the raw output into `dotfiles/manus/sleep-black-screen/logs/YYYY-MM-DD/…`.

4. Working hypothesis (based on current evidence):
   - Bucket: NVIDIA + Wayland + Hyprland resume path
   - Most likely fix to try first once confirmed: enable NVIDIA suspend/resume integration (power management + modesetting) in NixOS, then retest long suspend.

## Mistakes / corrections log (Manus requirement)
- None yet. Once we try a change that doesn’t help, record:
  - what we assumed,
  - what the evidence showed,
  - what we changed next.