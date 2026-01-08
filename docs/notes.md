# Notes — Investigate Home Manager `mutableFileGeneration` / "Copying mutable home files" pause

## Context / Symptom
- You’re seeing a **1m+ pause** during Home Manager activation.
- The slow step is reported as **`mutableFileGeneration`** and specifically **“Copying mutable home files”**.
- On the slow run, systemd stats indicated roughly **8.1G reads** and **1.8G writes**, consistent with HM copying large trees rather than symlinking.

## What we know from repo searches
- Local repo search did **not** find:
  - `mutableFileGeneration`
  - `Copying mutable home files`
  - `mutable home files`
  - `mutable.nix` references in local `*.nix`
- The only hit for `mutableGeneration` was in:
  - `hydenix_repo_og_cloned_docs/faq.md` (documentation example), not active code.
- Therefore the `mutableFileGeneration` step is **almost certainly introduced by Hydenix upstream Home Manager modules** (imported via `inputs.hydenix.homeModules.default`), not by a locally-authored activation hook.

## Local module that is *not* the culprit (but related)
- `modules/hm/overrides/hyde-local-state.nix` defines:
  - `home.activation.ensureHydeLocalState = lib.hm.dag.entryAfter [ "writeBoundary" ] '' ... ''`
- This hook only:
  - `mkdir -p` for known mutable state directories
  - converts symlinks back into directories for those paths
- It does **not** implement `mutableFileGeneration` itself.
- However, it indicates HyDE/Wallbash paths are a likely source of “mutable” file copying if upstream marks them `mutable = true`.

## Likely root cause
- In Hydenix, a custom `mutable.nix` module extends `home.file`, `xdg.configFile`, `xdg.dataFile` with a `mutable` option.
- When large directories are marked mutable, HM will **copy** them into place each activation to keep them writable, producing multi‑GB I/O.

## How to confirm exactly *what* is being copied
You need to inspect the **generated activation script** in the Nix store, using the store path shown in `systemctl status` for the Home Manager service (the `ExecStart` path).

Commands to run (expected flow):
1. Identify the generation path from `systemctl status`:
   - Look for something like:
     - `/nix/store/<hash>-home-manager-generation/activate`
2. Search inside that generation for the slow step:
   - Find the section containing `mutableFileGeneration` / “Copying mutable home files”.
3. Print enough lines after the match to reveal the actual list of paths being copied.

(Keep the raw output for later diffing; don’t paraphrase.)

## What to collect in logs (for later decision-making)
- The store generation path:
  - `/nix/store/...-home-manager-generation`
- The matching lines around:
  - `mutableFileGeneration`
  - “Copying mutable home files”
- The actual list of file/dir targets being copied.
- Optional: confirm the biggest offenders by eyeballing for:
  - `~/.config/hyde/themes`
  - `~/.config/hyde/wallbash`
  - `~/.local/share/hyde`
  - `~/.local/share/wallbash`
  - `~/.local/share/waybar/styles`
  - `~/.vscode/extensions/...`

## Fix strategies (choose after we know the copied paths)
Once you have the list, the fix is to reduce or eliminate large “mutable copy” targets:
- Prefer:
  - leaving big cache/theme/state directories unmanaged by HM (local directories)
  - or managing them as symlinks (non-mutable) if they don’t need runtime writes
- Avoid:
  - marking huge directory trees as `mutable = true` unless you accept the I/O

Next: after you collect the file list from the activation script, we can:
- map each copied path back to the responsible Hydenix module option
- override/disable just those upstream declarations in your `modules/hm` layer without breaking Hydenix theme/config management