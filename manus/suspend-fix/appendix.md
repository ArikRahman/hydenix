# Appendix — User-run commands & reproducibility notes (suspend/resume fix)

This appendix is for **commands you run manually** while testing/fixing suspend/resume. The goal is to keep the workflow reproducible and make it easy to correlate “what changed” with “what happened”.

> Project rule reminder: I only run `nix flake check` myself; you run `nixos-rebuild switch` (or equivalent) on your machine.

---

## A. Apply config changes (your standard rebuild)

### Switch to the new system generation
```/dev/null/nu#L1-3
z dotfiles; sudo nixos-rebuild switch --flake .#hydenix;
```

Notes:
- Run this after you’ve pulled/committed config changes you want to test.
- If you use a different hostname than `hydenix` in your flake outputs, adjust the `.#...` target accordingly.

---

## B. Verify evaluation/build before switching (safe preflight)

### Check the flake evaluates and builds
```/dev/null/nu#L1-3
z dotfiles; nix flake check -L;
```

Notes:
- This helps catch Nix evaluation errors before you attempt a system switch.
- If `flake check` fails, capture the full output in `manus/suspend-fix/logs/` and record it in `troubleshooting.md`.

---

## C. Suspend/resume test commands

### Suspend immediately
```/dev/null/nu#L1-3
sudo systemctl suspend;
```

Recommended testing protocol:
- Do a short suspend (~30 seconds), then a medium suspend (5–15 minutes).
- Keep variables controlled (battery vs AC, lid open vs closed, external monitor attached vs not).

---

## D. Log capture (most useful after hard power-cycle)

### Capture previous boot logs (after you reboot from a failed resume)
```/dev/null/nu#L1-6
# Saves the full previous boot journal.
journalctl -b -1 --no-pager | save -f manus/suspend-fix/logs/journal-b-1.txt;
```

### Capture filtered previous boot logs (suspend/resume + GPU keywords)
```/dev/null/nu#L1-12
journalctl -b -1 --no-pager
| lines
| where {|l| $l =~ 'PM:|systemd-sleep|suspend|resume|nvidia|NVRM|Xid|drm|i915|amdgpu|ACPI|s2idle|S3' }
| save -f manus/suspend-fix/logs/journal-b-1-filtered.txt;
```

### Capture current boot kernel messages
```/dev/null/nu#L1-3
dmesg | save -f manus/suspend-fix/logs/dmesg-current.txt;
```

### Record which suspend mode is active (s2idle vs deep)
```/dev/null/nu#L1-3
cat /sys/power/mem_sleep;
```

Interpretation:
- Output like `[s2idle] deep` means **s2idle** is active.
- Output like `s2idle [deep]` means **deep** is active.

---

## E. Quick “is the system alive?” checks (when resume is weird)

These only help **if input still works**. In your current failure mode (TTY switch doesn’t work), they may not be reachable, but keep them here for completeness.

### Check if suspend/resume units ran this boot
```/dev/null/nu#L1-10
journalctl -b --no-pager
| lines
| where {|l| $l =~ 'systemd-sleep|sleep.target|suspend.target|nvidia-suspend|nvidia-resume|nvidia-hibernate' }
| save -f manus/suspend-fix/logs/journal-b-sleep.txt;
```

---

## F. Reproducibility notes / operational discipline

### 1) Record every test run
For each attempt, update `manus/suspend-fix/troubleshooting.md` with:
- the exact config toggles changed,
- whether `nix flake check` passed,
- the exact rebuild command you ran,
- whether the machine required a hard power cycle,
- which logs you captured and where they’re saved.

### 2) Keep changes declarative and toggleable
Prefer:
- adding Nix options (module toggles) and kernel params via configuration,
- rather than ad-hoc edits in `/etc/` or imperatively echoing sysfs values.

### 3) Don’t lose history
If you need to disable a stanza:
- comment it out and annotate *why* (instead of deleting),
- so you can revert/compare behaviors later.

### 4) Commit/stage new files
This repo uses flake workflows where untracked files can cause confusion. If you add files under `dotfiles/manus/...`, make sure they’re committed when appropriate, and record that in the attempt log.

---

## G. What to do if you must hard power off (data preservation)
If the machine wedges so badly that:
- no TTY switching works,
- caps lock doesn’t toggle,
- and you can’t SSH in,

then it’s likely a **kernel/firmware/GPU resume wedge**. After reboot:
1) Immediately capture `journalctl -b -1` and the filtered log into `manus/suspend-fix/logs/`.
2) Note the exact time and what you were doing (lid state, external monitor, AC/battery).
3) Only then proceed to the next mitigation step (one change at a time).
