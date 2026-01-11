# Hibernate Debug — Task Plan (Manus)

## Goal
Identify why **hibernate does not work properly** on your Hydenix/NixOS system, and produce a minimal, correct Nix configuration change set to make hibernate reliable.

> “Does not work properly” can mean: fails to enter hibernate, instantly wakes, powers off but doesn’t resume, resumes to a black screen, or resumes but state is lost. This task plan targets the most common hard failure: **no resume configured**.

---

## Current Known Facts (from captured logs)
- Swap is present and active:
  - `/dev/nvme0n1p3` swap, size ~17G.
- Kernel cmd dispute:
  - `/proc/cmdline` contains **no** `resume=` parameter.
- NixOS hardware config contains `swapDevices` but **no** explicit `boot.resumeDevice`.
- `/sys/power/state` includes `disk` and `/sys/power/disk` includes `platform` → kernel advertises hibernate support.
- systemd targets are reachable (hibernate target reached/stopped) → systemd is attempting to hibernate.
- Inhibitors exist (`NetworkManager`, `UPower`, `hypridle`) but they’re `delay` inhibitors (normally not fatal).
- `dmesg` unreadable as user (`kernel.dmesg_restrict=1`) → for kernel-level suspend/hibernate errors we need root logs.

---

## Hypotheses (ranked)
1. **Missing resume configuration**:
   - Without `boot.resumeDevice` (and, in some setups, explicit `resume=`), the system can hibernate (write image) but cannot reliably resume (may cold boot, hang, or appear “broken”).
2. **Swap too small / image_size constraints**:
   - 17G swap may be insufficient depending on RAM usage. (Not confirmed; needs RAM size + typical usage.)
3. **Graphics/driver resume issues (Wayland/Hyprland + GPU drivers)**:
   - Could resume but black screen / compositor dead. (Needs journal of resume attempt.)
4. **Storage encryption / UUID mismatch / initrd missing resume hook**:
   - Not indicated yet (swap appears plain swap with UUID), but verify.
5. **BIOS/ACPI quirks**:
   - If platform hibernate is broken, kernel logs would show.

---

## Phase Plan

### Phase 0 — Define “not working properly” (you answer)
- [ ] Confirm symptom category:
  - [ ] A) hibernate option missing/greyed out
  - [ ] B) hibernate triggers but instantly wakes
  - [ ] C) hibernate powers off but on power button it cold boots (state lost)
  - [ ] D) resume hangs/black screen
  - [ ] E) other (describe)

**Exit criteria:** We can map the symptom to the right branch of fixes.

---

### Phase 1 — Verify prerequisites & collect authoritative logs (root)
Even though kernel advertises `disk`, we need the resume path correctness and the write/resume outcome.

- [ ] Capture:
  - [ ] `sudo journalctl -b -u systemd-hibernate.service -u systemd-sleep -u systemd-logind --no-pager`
  - [ ] `sudo dmesg -T | egrep -i 'hibernate|swsusp|PM: Image|resume|ACPI|error|fail|oom' | tail -n 300`
  - [ ] `cat /sys/power/resume` and `cat /sys/power/resume_offset`
  - [ ] RAM size: `free -h` (or `cat /proc/meminfo | head`)
  - [ ] `systemctl status systemd-hibernate.service --no-pager`

**Exit criteria:** We can tell if the kernel wrote an image and whether it found it on boot.

---

### Phase 2 — Implement the most likely fix: configure resume
Given current data, resume is not configured in the kernel cmdline and NixOS config doesn’t set it.

#### Proposed change set (target)
- [ ] Add `boot.resumeDevice = "/dev/disk/by-uuid/82250e78-4142-4376-bef7-200b513b7417";`
  - Use the swap UUID already present in `dotfiles/hardware-configuration.nix`.
- [ ] Optionally ensure the initrd knows resume:
  - NixOS should propagate resume via initrd when `boot.resumeDevice` is set.
- [ ] Avoid deleting anything; comment any replaced lines per project rules.

**Exit criteria:** After rebuild + reboot, `/proc/cmdline` contains a `resume=` param (or equivalent initrd arg), and `/sys/power/resume` reflects the correct device (major:minor).

---

### Phase 3 — Test hibernate deterministically
- [ ] Prepare a minimal test:
  - Save work, open a distinctive state (e.g., a text file in editor, note the time).
- [ ] Trigger hibernate:
  - `systemctl hibernate`
- [ ] Resume using power button.
- [ ] Validate:
  - Desktop state restored (not a fresh boot)
  - Check boot ID didn’t change unexpectedly (or compare `journalctl --list-boots`).
  - Look for `PM: Image restored successfully` in logs.

**Exit criteria:** Resume works at least 2 consecutive times.

---

### Phase 4 — If resume still fails: branch by symptom

#### Branch C (cold boot; state lost)
- [ ] Confirm whether the hibernate image is being written:
  - Look for `PM: Image saving done` and similar kernel/systemd log lines.
- [ ] If image writes but not found on boot:
  - [ ] Verify swap UUID matches actual swap (no device renumbering).
  - [ ] Consider adding explicit `boot.kernelParams = [ "resume=UUID=..." ];` only if Nix isn’t injecting it.

#### Branch D (black screen/hang on resume)
- [ ] Identify GPU and driver (Intel iGPU / NVIDIA / AMD).
- [ ] Collect root logs from resume attempt.
- [ ] Try known mitigations:
  - [ ] force different mem sleep state (s2idle vs deep) for suspend; for hibernate less applicable
  - [ ] disable fast boot / modern standby in BIOS
  - [ ] test switching compositor/session (e.g., plain tty resume to confirm kernel resumed)
  - [ ] add `boot.kernelParams` workarounds specific to GPU if logs indicate

#### Branch B (instantly wakes)
- [ ] Test `systemctl hibernate` from tty to exclude compositor wake triggers.
- [ ] Inspect wakeup sources (`/proc/acpi/wakeup` etc.) if needed.

**Exit criteria:** Identify the subsystem (resume config vs GPU vs ACPI) and apply targeted fix.

---

## Deliverables
- [ ] `dotfiles/manus/hibernate-debug/notes.md`
  - Raw findings: symptoms, logs excerpts, what was tested, what changed.
- [ ] `dotfiles/manus/hibernate-debug/findings_summary.md`
  - The final explanation + the exact Nix settings required.
- [ ] Nix config patch (likely in `dotfiles/modules/system/default.nix` or a new module under `dotfiles/modules/system/`):
  - Add `boot.resumeDevice` (and comments explaining why).
  - Avoid deleting lines: comment out any superseded config.

---

## Status
- Phase 0: ☐ not started
- Phase 1: ☐ not started (partial logs already captured, but missing root dmesg + active boot hibernate attempt logs)
- Phase 2: ☐ not started
- Phase 3: ☐ not started
- Phase 4: ☐ not started

---

## Next Action (smallest step)
You tell me what “hibernate not working properly” looks like on your machine (A–E above). Once confirmed, the next concrete step is to add `boot.resumeDevice` pointing at your swap UUID and rebuild.