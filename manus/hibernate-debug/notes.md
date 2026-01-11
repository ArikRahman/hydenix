# Hibernate Debug — Notes (Manus)

## Context
This repo is a Hydenix-based NixOS flake. You asked: “why does hibernate not work properly?”

These notes capture what was observed from configuration + captured command output, and where the relevant logs were saved in-repo.

---

## What “hibernate not working” means on this machine (confirmed)
You reported:
- **B)** hibernate triggers, but it **returns immediately** (acts like an abort / instantly wakes)
- and later **D)** when you come back after a while, resume can lead to a **black screen / stuck session**

This matches what the kernel and systemd logs show: the machine is *trying* to enter S4, but then bails out and resumes back to the running session; later, display stack instability (hyprland/wayland/GPU) can present as a black screen.

---

## Configuration observations (from repo)
### Swap is configured
`dotfiles/hardware-configuration.nix` includes a swap device:
- Swap UUID: `82250e78-4142-4376-bef7-200b513b7417`
- Device path (by UUID): `/dev/disk/by-uuid/82250e78-4142-4376-bef7-200b513b7417`

### No explicit resume configuration found
- `dotfiles/hardware-configuration.nix` has `swapDevices`, but no `boot.resumeDevice`.
- `dotfiles/configuration.nix` imports `./modules/system` and `./hardware-configuration.nix`, but contains no hibernate-specific configuration.
- `dotfiles/modules/system/default.nix` sets only audio-related `boot.kernelParams`:
  - `snd_hda_intel.power_save=0`
  - `snd_hda_intel.power_save_controller=N`

**Strong suspicion:** hibernate/resume is not fully configured (especially resume path), and the kernel is not consistently able to create/validate a hibernation image in swap.

---

## Runtime observations (from captured output)
### Swap is active
From `swapon --show`:
- `/dev/nvme0n1p3` swap ~17G (used ~356MB at capture time)

### Disk hibernate is supported by kernel
From `/sys/power/*`:
- `/sys/power/state`: `freeze mem disk`
- `/sys/power/disk`: `[platform] shutdown reboot suspend test_resume`
This indicates the kernel advertises hibernate capability (`disk`) and default mode appears to be `platform`.

### Kernel cmdline is missing a resume parameter
From `/proc/cmdline`:
- No `resume=` parameter present.

This aligns with missing `boot.resumeDevice` (or equivalent), which is typically required for reliable resume and for the kernel/systemd to manage hibernate state correctly across boots.

### systemd attempts hibernate, but returns to userspace (symptom B)
From systemd unit status output:
- `systemd-hibernate.service` logged:
  - `Performing sleep operation 'hibernate'...`
  - then `System returned from sleep operation 'hibernate'.`

That “returned” behavior is what you experience as “it hibernates but instantly wakes/aborts”.

### Kernel confirms why: no hibernation image found (key evidence)
From the root kernel log excerpt captured into `dotfiles/manus/hibernate-debug/root_sleep_resume_current_boot.log`, there is:

- `PM: Image not found (code -16)`

Immediately followed by a hibernation attempt sequence:
- `PM: hibernation: hibernation entry`
- `PM: hibernation: Creating image:`
- `ACPI: PM: Preparing to enter system sleep state S4`
…but then it transitions back out of S4 without completing a successful image write (no “Image saving done” / “powering down” sequence in the excerpt), and returns to the running session.

This is consistent with a hibernate attempt that cannot complete successfully and falls back to resuming the current session.

### GPU / graphics context (relevant to symptom D: black screen later)
From captured hardware info:
- Intel iGPU: `i915` in use
- NVIDIA dGPU: RTX 3050 Mobile with `nouveau` in use (not proprietary `nvidia`)

GPU drivers and Wayland compositors are common sources of “resume to black screen” issues when suspend/hibernate cycles occur, especially on hybrid graphics laptops.

---

## Log files saved (in repo)
Captured outputs were stored under:
- `dotfiles/manus/hibernate-debug/hibernate_debug.log`
  - swap status, lsblk, kernel cmdline, systemd sleep config, some journal excerpt from previous boot
- `dotfiles/manus/hibernate-debug/inhibitors_and_logind.log`
  - inhibitors list + merged logind config
- `dotfiles/manus/hibernate-debug/dmesg_permissions.log`
  - confirms `kernel.dmesg_restrict=1` and current user groups (why non-root dmesg failed earlier)
- `dotfiles/manus/hibernate-debug/resume_config.log`
  - confirms `/proc/cmdline` lacks `resume=`
- `dotfiles/manus/hibernate-debug/sys_power_and_targets.log`
  - `/sys/power` state + systemd target statuses
- `dotfiles/manus/hibernate-debug/session_and_gpu.log`
  - confirms `i915` for Intel and `nouveau` for NVIDIA dGPU
- `dotfiles/manus/hibernate-debug/root_sleep_resume_current_boot.log`
  - root journal + kernel messages; includes the critical `PM: Image not found (code -16)` line and the hibernate attempt sequence

---

## Working hypotheses (updated)
1. **Primary:** missing/incorrect resume configuration causes the kernel to not find/validate a hibernation image (`PM: Image not found (code -16)`), leading to hibernate abort/instant-return (your symptom B).
2. **Secondary:** even when sleep states are exercised, hybrid GPU + `nouveau` + Wayland compositor can yield black screens on resume later (your symptom D), independent of resume-device configuration.

---

## Proposed minimal fix direction
1. Configure resume explicitly in NixOS:
   - set `boot.resumeDevice` to `/dev/disk/by-uuid/82250e78-4142-4376-bef7-200b513b7417`
2. After that, if black screens persist, treat it as a GPU/compositor resume issue and iterate with targeted mitigations (often: switching to proprietary NVIDIA, PRIME config, or forcing iGPU-only depending on goals).

---

## Open questions (next)
1. When you trigger hibernate, does the machine ever fully power off, or does it always “return” quickly?
2. How much RAM do you have vs 17G swap? (If RAM usage is high, image creation can fail.)
3. Do you want to use the NVIDIA dGPU at all on battery/desktop, or is iGPU-only acceptable? (This affects the best fix for resume-black-screen issues.)

---