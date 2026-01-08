# Task Plan — Investigate & fix slow Home Manager `mutableFileGeneration`

## Goal
Reduce the ~1m+ pause during Home Manager activation caused by `mutableFileGeneration` / “Copying mutable home files” (multi‑GB reads/writes), by identifying what’s being copied and disabling or narrowing the mutable-copy behavior at the source (likely an imported Hydenix module).

## Constraints / Project Rules
- Follow Manus workflow (use Markdown files as working memory on disk).
- Prefer changes in `modules/` / Home Manager modules over ad-hoc config.
- Don’t delete lines; comment them out with a note explaining why.
- When I make a mistake, add a comment explaining what was wrong and how it was corrected.
- Avoid interactive debugging; capture outputs into log text files in the repo.

## Phases

### Phase 0 — Setup (tracking + logs)
- [x] Create `dotfiles/docs/notes.md` for findings and pasted logs.
- [ ] Create `dotfiles/docs/deliverable.md` for the final “what changed + why + how to verify” writeup.
- [x] Create `dotfiles/docs/logs/` directory for captured command outputs.

**Outputs**
- `dotfiles/docs/notes.md`
- `dotfiles/docs/deliverable.md`
- `dotfiles/docs/logs/…` (activation inspection, file lists, timings)

---

### Phase 1 — Confirm what’s being copied (ground truth)
**Purpose:** Determine exactly which paths are being copied during `mutableFileGeneration`.

Steps:
- [ ] Identify the Home Manager generation store path from the `systemctl status` output (`ExecStart=/nix/store/...-home-manager-generation/activate`).
- [ ] Dump the relevant activation script section to a log file:
  - Extract lines around `mutableFileGeneration`, `mutableGeneration`, or “Copying mutable home files”.
  - Extract the file list / rsync / cp commands that enumerate targets.
  - Save raw output to `dotfiles/docs/logs/hm-activate-mutableFileGeneration.txt` so we can diff before/after changes.
- [ ] Record:
  - Which paths are being copied
  - Total size / largest directories
  - Whether it’s `~/.config`, `~/.local/share`, theme caches, editor profiles, etc.

**Success criteria**
- [ ] I have an explicit list of copied paths (not guesses), stored in `docs/logs/…` and summarized in `docs/notes.md`.

**Notes**
- Repo search not finding `mutableFileGeneration` strongly suggests the step is coming from Hydenix’s imported Home Manager module(s), not local code.

---

### Phase 2 — Locate the declaring module(s)
**Purpose:** Find where those paths are declared as mutable-copied files.

Steps:
- [ ] Search Hydenix inputs and local modules for:
  - `mutable.nix` module usage
  - extended options like `mutable = true`
  - any wrappers around `home.file`, `xdg.configFile`, `xdg.dataFile`
- [ ] Map each copied path to its declaration:
  - Which module sets it
  - Whether it is marked mutable intentionally (runtime-edited config/state) or accidentally (should be symlinked)

**Success criteria**
- [ ] For each copied path, I know the option source (module + location) that causes it to be “mutable copied”.

---

### Phase 3 — Choose the fix strategy
Pick the least invasive option that eliminates the big copy.

Candidate strategies:
1. **Stop managing huge mutable trees**  
   - Disable upstream declarations for large state directories (themes/caches) so HM doesn’t try to copy them.
2. **Convert to symlinked management (non-mutable)** for large static config  
   - If a path doesn’t need runtime writes, remove `mutable = true` and use standard HM symlinks.
3. **Narrow the scope**  
   - Keep only a minimal set of genuinely mutable files as copied (single file configs), avoid whole directories.
4. **Move runtime state out of “managed” paths**  
   - Prefer XDG state/cache dirs and ensure they are *not* declared as HM-managed files.

**Success criteria**
- [ ] I select a concrete plan for each problematic path (disable, narrow, or convert).

---

### Phase 4 — Implement changes (with safety)
Steps:
- [ ] Apply overrides in `modules/hm/` (preferred) to disable or adjust offending upstream file declarations.
- [ ] Add comments explaining:
  - Why this was slow (multi‑GB copy)
  - Why this path should be local state vs declaratively managed
  - What upstream behavior we’re overriding

**Rules compliance**
- [ ] Avoid deleting lines; comment out and annotate.
- [ ] If I revise a decision, note what was wrong and how it was corrected.

---

### Phase 5 — Verify impact (time + I/O)
Steps:
- [ ] Rebuild and capture activation logs to `docs/logs/`.
- [ ] Compare before/after:
  - Activation duration
  - Read/write bytes for the HM service (from `systemctl status` / `systemd-analyze` if available)
- [ ] Confirm Hydenix theme functionality still works, and mutable local state dirs remain writable.

**Success criteria**
- [ ] `mutableFileGeneration` no longer runs, or runs quickly (no multi‑GB copy), and activation is materially faster.

---

## Deliverables
- `dotfiles/docs/notes.md` — findings, copied-path list, module sources, logs references
- `dotfiles/docs/deliverable.md` — final explanation + exact changes + verification steps
- Fix committed via configuration changes in `dotfiles/modules/hm/...`

## Open Questions (to answer during Phase 1)
- Which specific paths account for the 8.1G reads / 1.8G writes?
- Are these Hydenix theme directories under `~/.config/hydenix/themes` or HyDE/Wallbash state?
- Is the copying triggered by Hydenix’s `mutable.nix` module or another mechanism?

## Current Status
- Phase 0: In progress (task plan created)
- Next: Phase 1 — Inspect activation script for copied file list