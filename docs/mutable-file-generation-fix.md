# Fixing slow Home Manager “mutable file generation” in this Hydenix setup

This repo is based on Hydenix (flake) and uses Home Manager through Hydenix’s modules. If your rebuild/activation pauses for a long time and you see log lines like:

- `mutableFileGeneration`
- `Copying mutable home files`

…that pause is typically **Home Manager copying files/directories** into your `$HOME` so they’re writable (“mutable”). If a large directory tree is marked mutable (themes, caches, editor profiles, wallpapers, etc.), it can easily turn into multi‑GB reads/writes every activation.

This document shows how to **identify what is being copied** and the **practical ways to stop the expensive copy** in this Hydenix layout.

---

## 1) Confirm it’s Home Manager and capture the evidence

You want two things:

1. The **systemd unit** that ran home-manager activation
2. The exact **activation script** that contains the “Copying mutable home files” step

### 1.1 Find the activation unit and store path
On NixOS + HM-as-a-module the unit is usually something like:

- `home-manager-<user>.service` (system unit), or
- `home-manager-<user>.service` under your user session (less common for NixOS module mode)

Run:

```/dev/null/sh#L1-8
# Replace hydenix with your username if needed
systemctl status home-manager-hydenix.service -n 200 --no-pager

# Also check user units if you might be using them
systemctl --user status home-manager.service -n 200 --no-pager
```

Look for an `ExecStart=` line containing a store path like:

- `/nix/store/<hash>-home-manager-generation/activate`

Copy that path; you’ll use it below.

### 1.2 Inspect the activation script around the slow step
Once you have the generation directory (example variable `GEN`), inspect it:

```/dev/null/sh#L1-12
GEN="/nix/store/<hash>-home-manager-generation"

# Show the relevant section
sed -n '/mutableFileGeneration/,+220p' "$GEN/activate" | sed -n '1,220p'

# If the script prints “Copying mutable home files”, find the exact block
grep -nE 'mutableFileGeneration|Copying mutable home files' "$GEN/activate"
```

What you’re looking for:

- The **list of paths** being treated as mutable
- Whether it is copying individual files or recursively copying directories
- Any obvious “big trees” (e.g. `~/.config/hyde/themes`, wallpapers, caches, `~/.local/share` trees, etc.)

---

## 2) Where it likely comes from in this repo

Your own repo search won’t necessarily show `mutableFileGeneration` because Hydenix can import a custom “mutable files” module from the Hydenix input. In other words:

- The *implementation* lives upstream (in Hydenix).
- Your config *enables it* by setting some option(s) or by marking file entries as mutable.

In this repo you already have a local Home Manager override module:

- `modules/hm/overrides/hyde-local-state.nix`

That file **creates local directories** for HyDE “state” (themes, wallbash caches, waybar styles, etc.) and explicitly documents that if upstream tries to manage those targets via `xdg.configFile`/`home.file`, the right fix is to **disable upstream declarations**.

That is a strong hint: the big copying is probably Hydenix trying to “manage” a huge mutable subtree related to HyDE.

---

## 3) Typical root causes

### Cause A: A directory tree is marked `mutable = true`
Hydenix’s `mutable.nix` concept (documented in the upstream FAQ) extends options like:

- `home.file`
- `xdg.configFile`
- `xdg.dataFile`

…with a `mutable` flag. When set, Home Manager **copies** instead of symlinking so the path becomes writable.

If the target is a directory with lots of data, activation becomes I/O heavy.

### Cause B: Accidentally managing runtime caches/state declaratively
Paths like these are almost always a bad idea to manage as store-backed files:

- caches, generated assets, wallpaper caches
- theme repositories that are mutated by runtime tools
- editor extension stores (`~/.vscode/extensions`) and similar

Even if you want those directories to exist, you generally want them:
- created as real dirs (not symlinks), and
- excluded from “mutable copy” mechanisms.

---

## 4) Fix strategy (choose one)

You have three reliable approaches. The best one depends on what you find in `$GEN/activate`.

### Strategy 1 (best): Stop marking big trees as mutable; manage only the real config files
**Goal:** keep the real config declarative (small files), keep state dirs local.

How to do it:

1. Identify the huge targets in the activation script.
2. Find which module declares them as mutable.

In Hydenix-style setups, the declarations often live under Hydenix options such as theme/hyde modules, or file declarations.

Once located, change the config so that:
- only small config files are managed by HM
- state dirs are not managed by HM at all

**Practical example of the intent (pseudo):**

- Keep: `~/.config/hyde/config.toml` managed by HM
- Do NOT manage: `~/.config/hyde/themes`, `~/.config/hyde/wallbash`, `~/.local/share/hyde`, etc.

Your `modules/hm/overrides/hyde-local-state.nix` already implements the “do not manage state; just ensure directories exist” side.

### Strategy 2: Disable the upstream “mutable files” feature (if you don’t need it)
If you don’t actually need any mutable copying behavior, disabling it can eliminate the entire step.

Because the implementation is upstream, the exact option will vary. The process to do it safely is:

1. Search in the Hydenix input for `mutable.nix` / `mutable` options.
2. Identify the toggle option (if present).
3. Disable it in `modules/hm/default.nix` (preferred) or in an override module.

If there is no clean toggle, Strategy 1 (stop declaring mutable targets) is still the best.

### Strategy 3: Reduce what gets copied by narrowing the mutable set
Sometimes you do need a mutable directory, but you can shrink it:

- Split a big directory into:
  - a small mutable config file
  - a separate local directory created at activation time
- Or manage only a subset of files instead of an entire tree

For example:
- Manage `~/.config/hyde/config.toml`
- Create `~/.config/hyde/themes` as a local dir (not HM-managed), as you already do.

---

## 5) A concrete “what to change” checklist for this Hydenix repo

Use this checklist once you know the copied targets.

### 5.1 If any of these show up in the copied list, treat them as state
Common HyDE/Wallbash state dirs:

- `~/.config/hyde/themes`
- `~/.config/hyde/wallbash`
- `~/.local/share/hyde`
- `~/.local/share/wallbash`
- `~/.local/share/waybar/styles`
- `~/.vscode/extensions/prasanthrangan.wallbash`

**Desired behavior:** these should exist locally and be writable, but should **not** be store-managed and should **not** be copied every activation.

You already have a module (`modules/hm/overrides/hyde-local-state.nix`) that:
- creates these directories during activation, and
- asserts if `xdg.configFile."hyde/themes"` or `xdg.configFile."hyde/wallbash"` are being managed by HM.

If those assertions start firing, it means upstream is managing them and you need to disable the upstream declaration (next item).

### 5.2 Disable the upstream file declarations (when you find them)
When you locate an upstream declaration that’s causing mutables, you typically fix it one of these ways:

- Set the upstream Hydenix option that enables that feature to `false`
- Override the specific HM file entry with `lib.mkForce null` or by disabling a module
- Stop importing the module that provides the giant file set (last resort)

**Important:** Prefer narrowly disabling the specific file entries rather than turning off Hydenix wholesale.

---

## 6) Validate the fix

After making changes:

1. Rebuild:
```/dev/null/sh#L1-2
z dotfiles
sudo nixos-rebuild switch --flake .#hydenix
```

2. Check activation timing and I/O:
```/dev/null/sh#L1-8
systemctl status home-manager-hydenix.service -n 200 --no-pager

# Optional: show last run resource usage
systemctl show home-manager-hydenix.service -p ExecMainStartTimestamp -p ExecMainExitTimestamp -p CPUUsageNSec -p IOReadBytes -p IOWriteBytes
```

3. Re-check the activation script from the new generation and confirm:
- The big trees are not in the mutable copy list anymore, or
- The mutable copy step is gone / dramatically smaller.

---

## 7) What I need from you if it still isn’t clear

If you paste the following, I can tell you exactly what to disable/override:

1. From `systemctl status ...`:
   - the `ExecStart=` store path
   - the lines around `Copying mutable home files`

2. From the activation script:
   - ~100–200 lines around the `mutableFileGeneration` block

That lets us pinpoint the exact targets and the module responsible, and then make a minimal, correct override in `modules/hm/` (preferred).