# Notes — Investigate Home Manager `mutableFileGeneration` / "Copying mutable home files" pause

## Context / Symptom
- You’re seeing a **1m+ pause** during Home Manager activation.
- The slow step is reported as **`mutableFileGeneration`** and specifically **“Copying mutable home files”**.
- On the slow run, systemd stats indicated roughly **8.1G reads** and **1.7G writes**, consistent with HM copying large trees rather than symlinking.

## Ground truth from `systemctl status`
From:
- `systemctl status home-manager-hydenix.service -n 200 --no-pager`

Key lines:
- `ExecStart=/nix/store/dhrdrka72xl4nkpm2yc8ha2kpm0ssapq-hm-setup-env /nix/store/cdf80fllij4fw4i53770dsm93ghjcpix-home-manager-generation`
- `IO: 8G read, 1.7G written`
- `CPU: 1min 28.988s`

Activation timeline excerpt (important bits):
- `Activating linkGeneration`
- `Cleaning up orphan links from /home/hydenix`
- Multiple log lines referencing paths under:
  - `/home/hydenix/.config/hyde/themes/...`
- `Activating ensureHydeLocalState`
- `Activating mutableFileGeneration`
- `Copying mutable home files for /home/hydenix`
- (pause ~82s here)
- Afterwards: `Activating setTheme` → theme set to `Catppuccin Mocha`

Also noted:
- The user systemd session is degraded due to:
  - `fix-ariks-disk-perms.path` and `fix-ariks-disk-perms.service` failing
  - This is a separate issue from the copy pause, but it does show up during `reloadSystemd`.

## Root cause (confirmed from activation script snippet)
The slow 8G/1.7G I/O step is `mutableFileGeneration`, which is doing *recursive copies* (`cp -r --remove-destination --no-preserve=mode`) of Hydenix/HyDE-provided “mutable” targets into your home directory so they’re writable at runtime.

This behavior is not implemented in your local repo (no local `mutable.nix` / `mutable = true` hits); it’s coming from an imported Hydenix Home Manager module, which generates the `mutableFileGeneration` activation step.

## Exact mutable copy targets observed (from the snippet you pasted)
From the activation script block around `mutableFileGeneration`:

- HyDE “modified configs” copied from a store path into XDG config targets (examples shown):
  - `/nix/store/0nbbgpa0zkay9zcs5ici0g9h2iirx63m-hyde-modified/Configs/.config/Kvantum/kvantum.kvconfig` -> `.config/Kvantum/kvantum.kvconfig`
  - `/nix/store/0nbbgpa0zkay9zcs5ici0g9h2iirx63m-hyde-modified/Configs/.config/Kvantum/wallbash/wallbash.kvconfig` -> `.config/Kvantum/wallbash/wallbash.kvconfig`
  - `/nix/store/0nbbgpa0zkay9zcs5ici0g9h2iirx63m-hyde-modified/Configs/.config/Kvantum/wallbash/wallbash.svg` -> `.config/Kvantum/wallbash/wallbash.svg`
  - `/nix/store/0nbbgpa0zkay9zcs5ici0g9h2iirx63m-hyde-modified/Configs/.config/dunst/dunst.conf` -> `.config/dunst/dunst.conf`
  - `/nix/store/0nbbgpa0zkay9zcs5ici0g9h2iirx63m-hyde-modified/Configs/.config/dunst/dunstrc` -> `.config/dunst/dunstrc`
  - `/nix/store/0nbbgpa0zkay9zcs5ici0g9h2iirx63m-hyde-modified/Configs/.config/gtk-3.0/settings.ini` -> `.config/gtk-3.0/settings.ini`
  - `/nix/store/0nbbgpa0zkay9zcs5ici0g9h2iirx63m-hyde-modified/Configs/.config/hyde/config.toml` -> `.config/hyde/config.toml`

- HyDE theme directories copied recursively into `.config/hyde/themes/*` (examples shown):
  - `/nix/store/6nvskk2zlphz7dhb4qnz9spirdx04a99-AbyssGreen/share/hyde/themes/AbyssGreen` -> `.config/hyde/themes/AbyssGreen`
  - `/nix/store/k8bldl6qdqbb1nfhkybmj6ca3bl8bxw7-AncientAliens/share/hyde/themes/AncientAliens` -> `.config/hyde/themes/AncientAliens`
  - `/nix/store/9f4d367x5h2c0nk48a7idy6lrc1im9bg-Another-World/share/hyde/themes/Another World` -> `.config/hyde/themes/Another World`
  - `/nix/store/sii12yic95wjlhsf0ilah6h14pq7dir2-Bad-Blood/share/hyde/themes/Bad Blood` -> `.config/hyde/themes/Bad Blood`
  - `/nix/store/db0gfac0lpr4598asbwxdmc5i3mg61m5-BlueSky/share/hyde/themes/BlueSky` -> `.config/hyde/themes/BlueSky`

- Post-copy permission adjustments are applied:
  - For directories: `find <target> -type f ... chmod u+wx` for files detected as executable/script (or `.sh` suffix)
  - For single files: `file -b <target>` check + `chmod u+wx` when needed

The large I/O is consistent with recursively copying many theme directories under `.config/hyde/themes`.

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

## Likely root cause (updated)
- The systemd log already shows activity under `~/.config/hyde/themes/...`, and then `mutableFileGeneration` does a giant copy.
- Most likely: Hydenix upstream is marking one or more HyDE/Wallbash/theme trees as “mutable”, triggering recursive copying during activation.

## Current next step (required to proceed)
Inspect the generated activation script for the exact copy list and commands.

You already have the generation store directory from `ExecStart`:
- `/nix/store/cdf80fllij4fw4i53770dsm93ghjcpix-home-manager-generation`

Next, extract the mutable copy block and capture it into a repo log file (so we can diff before/after):
- Find the matching lines around `mutableFileGeneration` / “Copying mutable home files”.
- Print a few hundred lines after the match to reveal the actual targets being copied.

Once we have that list, we can make a minimal override in `modules/hm/` to stop declaring the huge trees as mutable-copied (likely HyDE theme/state dirs), while keeping small, real config files declarative.