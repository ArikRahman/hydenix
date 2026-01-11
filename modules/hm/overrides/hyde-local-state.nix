{ lib, config, ... }:

let
  /*
    Goal (Option A):
    - Keep HyDE "runtime state" directories local/mutable so they don't get
      constantly replaced/rewritten by Home Manager (which leads to timeouts,
      conflicts, and backup spam).
    - Still allow Home Manager (and Hydenix) to manage the *real* configuration
      file(s) as the source of truth (ex: `~/.config/hyde/config.toml`).

    Background:
    HyDE/Wallbash commonly generate/cache assets under:
      - ~/.config/hyde/themes
      - ~/.config/hyde/wallbash
      - ~/.local/share/hyde
      - ~/.local/share/wallbash
      - ~/.local/share/waybar/styles
      - ~/.vscode/extensions/prasanthrangan.wallbash

    Those paths behave like mutable state. When HM tries to manage them,
    rebuilds can become slow or conflict-y, and HM will create lots of backups.
  */

  xdgConfig = "${config.xdg.configHome}";
  xdgData = "${config.xdg.dataHome}";

  hydeConfigDir = "${xdgConfig}/hyde";
  hydeThemesDir = "${hydeConfigDir}/themes";
  hydeWallbashDir = "${hydeConfigDir}/wallbash";

  hydeDataDir = "${xdgData}/hyde";
  wallbashDataDir = "${xdgData}/wallbash";
  waybarStylesDir = "${xdgData}/waybar/styles";

  # VSCode's extensions are mutable by design (downloaded/updated by VSCode).
  vscodeExtDir = "${config.home.homeDirectory}/.vscode/extensions";
  wallbashVscodeExtDir = "${vscodeExtDir}/prasanthrangan.wallbash";

in
{
  /*
    IMPORTANT: This module is intentionally conservative:
    - It does not attempt to "own" these directories as symlinks to the store.
    - It simply ensures they exist as real directories in $HOME so that if
      something upstream tries to overlay them, your session still has a local
      mutable place to write.

    If upstream Hydenix tries to manage these exact paths via `xdg.configFile`
    or `home.file`, a stronger fix is to *disable* those upstream file entries.
    Because upstream option names vary, I’m not guessing them here.

    Next step (when you wire this in):
    - Import this module from your `modules/hm/default.nix`.
    - Rebuild once.
    - If rebuild still reports file conflicts for any of these targets, we then
      add explicit overrides to disable the upstream declarations (once we know
      precisely which option/target is responsible).
  */

  # Ensure sane defaults for XDG homes (Hydenix/HM typically sets these anyway).
  xdg.enable = lib.mkDefault true;

  # Create local mutable directories that should NOT be store-managed.
  #
  # This avoids the "I must rm -rf these paths" troubleshooting loop by making
  # sure they exist and are writable at activation time.
  home.activation.ensureHydeLocalState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -euo pipefail

    mkdir -p \
      '${hydeThemesDir}' \
      '${hydeWallbashDir}' \
      '${hydeDataDir}' \
      '${wallbashDataDir}' \
      '${waybarStylesDir}' \
      '${vscodeExtDir}'

    # If a previous build left any of these as symlinks into the Nix store,
    # replace them with real directories.
    #
    # NOTE: This is intentionally limited to the known *state* dirs. We do
    # NOT touch `${hydeConfigDir}/config.toml` because that one *should*
    # stay declaratively managed.
    for p in \
      '${hydeThemesDir}' \
      '${hydeWallbashDir}' \
      '${hydeDataDir}' \
      '${wallbashDataDir}' \
      '${waybarStylesDir}' \
      '${vscodeExtDir}'
    do
      if [ -L "$p" ]; then
        rm -f "$p"
        mkdir -p "$p"
      fi
    done

    # Same idea, but for the wallbash VSCode extension directory: if it got
    # pinned/linked somehow, revert it to local state.
    if [ -L '${wallbashVscodeExtDir}' ]; then
      rm -f '${wallbashVscodeExtDir}'
      mkdir -p '${wallbashVscodeExtDir}'
    fi
  '';

  /*
    Guard rails:

    If you (or an upstream module) tries to declare these as HM-managed files,
    HM may still attempt to link them, which defeats the point.

    I’m adding assertions that *fail early* with a helpful message if this
    module itself is later extended to manage those targets.

    (We cannot reliably introspect all upstream file declarations here without
    knowing their exact option structure.)
  */
  assertions = [
    {
      assertion = !(config.xdg.configFile ? "hyde/themes");
      message = ''
        HyDE local-state policy violation:
        `xdg.configFile."hyde/themes"` is being managed by Home Manager.

        Fix: remove/disable that file declaration so `${hydeThemesDir}` remains local/mutable.
      '';
    }
    {
      assertion = !(config.xdg.configFile ? "hyde/wallbash");
      message = ''
        HyDE local-state policy violation:
        `xdg.configFile."hyde/wallbash"` is being managed by Home Manager.

        Fix: remove/disable that file declaration so `${hydeWallbashDir}` remains local/mutable.
      '';
    }
  ];
}
