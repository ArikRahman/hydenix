# Task Plan: Suspend/Sleep Resume → Black Screen / Unresponsive

## Goal
Identify why your system resumes from suspend/sleep to a black screen or becomes unresponsive after “a while”, and apply a minimal, reversible fix in your Hydenix (NixOS flake) configuration.

## Scope / Non-goals
- Scope: NixOS + Hydenix config, systemd sleep pipeline, GPU/driver stack, display manager/Wayland/X11, kernel parameters, log-based root cause analysis.
- Non-goals: Random trial-and-error toggles without logs; permanent changes without a rollback path.

## Assumptions to confirm
- Hardware: (NVIDIA / AMD / Intel), laptop vs desktop, external monitors/docking.
- Session: Wayland vs X11.
- Display manager: SDDM / GDM / greetd / etc.
- Suspend mode: `s2idle` vs `deep` (ACPI).

## Phase 0 — Repro + “Definition of Done”
### What “fixed” means
- You can suspend for >= 30–60 minutes and resume reliably.
- Display lights up, compositor/DM returns, keyboard/mouse responsive.
- No recurring GPU reset errors in logs.

### Repro notes to collect
- Suspend method: lid close / power menu / `systemctl suspend`
- Time before resume fails (e.g., 5 min vs 2 hours)
- External displays connected? USB-C dock? DP/HDMI?
- Does the machine *actually* wake (fans/keyboard backlight/SSH reachable) while screen stays black?

**Checkpoint:** Write the above into `dotfiles/manus/sleep-black-screen/notes.md` as you gather it.

## Phase 1 — Log capture (root-cause evidence)
### Primary logs to capture after a failed resume
- Current and previous boot journal:
  - `journalctl -b`
  - `journalctl -b -1`
- Sleep-related journal slice:
  - `journalctl -b | grep -Ei 'suspend|sleep|resume|wakeup|acpi|pm:'`
- GPU-specific clues:
  - For NVIDIA: `journalctl -b | grep -Ei 'nvrm|nouveau|nvidia|xid'`
  - For AMD: `journalctl -b | grep -Ei 'amdgpu|ring|gpu reset'`
  - For Intel: `journalctl -b | grep -Ei 'i915|drm|gpu hang'`
- Kernel ring buffer:
  - `dmesg -T | tail -n 300`

### How to handle “it’s black and I can’t see anything”
- Try switching to a TTY: `Ctrl`+`Alt`+`F2` (or F3/F4).
- If network still works, SSH in from another device and collect logs.
- If you must hard power off, the evidence is in `-1` boot logs.

**Checkpoint:** Save raw command outputs into a dated file under:
- `dotfiles/manus/sleep-black-screen/logs/YYYY-MM-DD/…`
(Keep it plain text. Don’t summarize yet—store raw logs.)

## Phase 2 — Categorize the failure mode
Based on evidence, classify into one bucket (you can revise later):

1. **System resumes but display stack is stuck**
   - SSH works, audio works, keyboard toggles LEDs, but screen black.
2. **GPU driver fails to re-init / GPU reset loop**
   - “GPU hang”, “Xid”, “ring timeout”, “failed to resume”
3. **Display manager/compositor doesn’t come back**
   - SDDM/GDM/greetd errors; Wayland compositor crash.
4. **Suspend mode incompatibility (s2idle vs deep)**
   - Works only for short sleeps; longer sleeps fail; ACPI wake quirks.
5. **Hybrid graphics / external monitor / dock issue**
   - Fails mainly when docked or with external display.
6. **Kernel regression**
   - Started after kernel upgrade; previous kernel worked.

**Checkpoint:** Record which bucket(s) match and which log lines support it in `notes.md`.

## Phase 3 — Apply the smallest reversible fix (one change at a time)
> Rule: one change per rebuild/test; always note what you changed and why.

### Candidate fix set (choose based on bucket)
#### A) NVIDIA-specific common fixes
- Ensure you’re using the proprietary driver (not nouveau) if appropriate.
- Enable NVIDIA suspend/resume services (systemd helpers) if you’re on proprietary.
- Consider forcing modeset and enabling power management options known to help resume.
- If on Wayland, test X11 (or vice versa) to isolate compositor vs driver.

#### B) AMD/Intel DRM resume issues
- Test different suspend mode (`deep` vs `s2idle`).
- Add/adjust kernel parameters related to runtime PM or DC (display core) (AMD).
- Consider kernel package change (LTS vs latest) if logs indicate regression.

#### C) Display manager / Wayland compositor issues
- Switch session type (Wayland ↔ X11) as a diagnostic step.
- Add a post-resume hook to restart the display manager only if evidence shows it’s stuck.
  - Prefer fixing underlying GPU resume if possible; restarting DM is a workaround.

#### D) General sleep configuration
- Confirm systemd-sleep is used and not conflicting with vendor scripts.
- Check lid switch handling and logind settings if the problem is lid-related.

**Safety note:** Keep rollback easy. Don’t remove existing config—comment out with an explanation.

## Phase 4 — Implement in Hydenix (NixOS modules preferred)
### Where changes should live
- Prefer `dotfiles/modules/system/**` for system-level changes.
- Only touch `configuration.nix` if needed to wire modules.
- Update `flake.nix` only if adding new inputs (unlikely for this).

### Implementation pattern
- Add a dedicated module for sleep/resume tweaks (so it’s easy to disable).
- Include comments explaining:
  - the symptom,
  - the log evidence,
  - why the chosen option is expected to help,
  - how to revert.

**Checkpoint:** In `notes.md`, list:
- file(s) edited
- options added
- the exact rationale + supporting log lines

## Phase 5 — Test matrix
Run a consistent test matrix after each change:

1. Suspend 5 minutes → resume
2. Suspend 30 minutes → resume
3. Suspend 60+ minutes → resume
4. Repeat with:
   - external monitor attached (if relevant)
   - lid close/open (if laptop)
   - AC vs battery (if laptop)

Record pass/fail in `task_plan.md` and detailed notes in `notes.md`.

## Phase 6 — Decide on “final state”
### If you find a clear root cause
- Keep the minimal fix.
- Add a short doc note in your troubleshooting docs (optional).

### If it’s a kernel/driver regression
- Pin to a known-good kernel or driver version (documented, reversible).
- Keep evidence links: kernel version, `uname -a`, offending log lines.

## Progress Tracker
- [ ] Phase 0: Repro notes captured
- [ ] Phase 1: Logs captured (current + previous boot)
- [ ] Phase 2: Failure bucket identified
- [ ] Phase 3: One minimal fix selected
- [ ] Phase 4: Implemented as a module with comments
- [ ] Phase 5: Test matrix passed (>= 60 min suspend)
- [ ] Phase 6: Document + cleanup

## Immediate next action (do this next)
1. After the next black-screen resume, collect `journalctl -b -1` and GPU-filtered journal output.
2. Determine whether SSH/TTY works during the black screen (this single fact narrows the root cause drastically).
3. Put the raw logs and those observations into `notes.md`.