# Hibernate Debug — Findings Summary (Manus)

## Summary (confirmed symptoms + most likely root causes)
On your current Hydenix/NixOS setup you’re seeing two behaviors:

- **B) Hibernate triggers but “returns immediately”** (acts like an abort / instant wake)
- **D) Later you sometimes come back to a black screen / stuck graphics session**

The logs we captured line up with *two* likely issues:

1. **Primary: resume/hibernation image path not configured**
   - Swap exists and is active: `/dev/nvme0n1p3` (~17G), UUID `82250e78-4142-4376-bef7-200b513b7417`.
   - Kernel advertises hibernate capability:
     - `/sys/power/state` contains `disk`
     - `/sys/power/disk` offers hibernate modes and defaults to `[platform]`
   - Your kernel command line (`/proc/cmdline`) contains **no** `resume=` parameter.
   - Your Nix config defines `swapDevices`, but does **not** set `boot.resumeDevice`.

   Most importantly, the kernel log shows:
   - `PM: Image not found (code -16)`

   That message is a strong indicator the kernel can’t find/validate a hibernation image where it expects one, which commonly yields exactly what you observe as symptom **B**: systemd runs hibernate, then the system “returns” back to userspace instead of powering down.

2. **Secondary: hybrid graphics resume instability (Wayland/compositor + GPU drivers)**
   Your machine is hybrid graphics:
   - Intel iGPU uses `i915`
   - NVIDIA RTX 3050 Mobile is currently using `nouveau`

   Even after we make hibernate itself reliable, hybrid GPU + `nouveau` + Wayland is a common combination for “resume to black screen” (symptom **D**). That’s usually a separate, graphics-stack problem.

## Minimal fix (do this first)
Configure NixOS to resume from your swap partition UUID.

Use the swap UUID already present in your hardware config:
- `82250e78-4142-4376-bef7-200b513b7417`

Set:
- `boot.resumeDevice = "/dev/disk/by-uuid/82250e78-4142-4376-bef7-200b513b7417";`

### Where to put it (repo conventions)
Prefer adding this to a system module rather than editing `hardware-configuration.nix` directly. In this repo, the most fitting place is:
- `dotfiles/modules/system/default.nix`
(or create `dotfiles/modules/system/hibernate.nix` and import it from `dotfiles/modules/system/default.nix`).

Also follow the project rule: **don’t delete lines**—comment out anything you replace and add a note explaining why.

## Verification steps (after rebuild + reboot)
After applying the change and rebuilding:
1. Confirm resume is actually configured:
   - Check `/proc/cmdline` for a `resume=` entry (or otherwise confirm NixOS injected resume handling into initrd).
2. Re-test symptom B:
   - Run `systemctl hibernate` and confirm it no longer “returns immediately”.
3. Re-test symptom D:
   - Hibernate, wait a while, then resume and check if the graphics session reliably returns.

## Follow-ups if black screen persists (likely)
If hibernate stops aborting but you still see black screens on resume, treat that as **GPU/compositor resume** work:
- With your current stack (`i915` + `nouveau`), the next best fixes are usually about GPU driver selection and hybrid-graphics configuration (often moving to proprietary NVIDIA + PRIME, or forcing iGPU-only depending on your goals).

## Next question (to choose the right GPU-resume path)
Do you want/need the NVIDIA dGPU active (gaming/performance), or are you okay with **iGPU-only** for stability/battery?