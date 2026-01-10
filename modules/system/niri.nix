{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:

let
  cfg = config.hydenix.system.niri;

  /*
    Niri (Wayland compositor) integration via `sodiboo/niri-flake`.

    Why this module exists:
    - Keep your repo clean/maintainable by isolating Niri-specific knobs.
    - Avoid turning on Niri implicitly; you opt-in with `hydenix.system.niri.enable`.
    - Let the upstream module (`inputs.niri.nixosModules.niri`) do the heavy lifting
      (session registration, portals, polkit agent, etc.) while we provide sane toggles.

    Upstream facts (from `sodiboo/niri-flake`):
    - NixOS module: `inputs.niri.nixosModules.niri`
    - Enable option: `programs.niri.enable = true;`
    - Packages: `inputs.niri.packages.${system}.niri-stable` and `...niri-unstable`
    - Cache option: `niri-flake.cache.enable` (default true in upstream module)
  */

  system = pkgs.stdenv.hostPlatform.system;

  # Map our “channel” choice to an upstream package derivation.
  chosenPackage =
    if cfg.channel == "stable" then
      inputs.niri.packages.${system}.niri-stable
    else
      inputs.niri.packages.${system}.niri-unstable;

in
{
  options.hydenix.system.niri = {
    enable = lib.mkEnableOption ''
      Enable the Niri Wayland compositor (via `sodiboo/niri-flake`).
    '';

    channel = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "unstable"
      ];
      default = "stable";
      description = ''
        Which upstream niri build to use.

        - "stable"   -> `inputs.niri.packages.${system}.niri-stable`
        - "unstable" -> `inputs.niri.packages.${system}.niri-unstable`
      '';
    };

    enableCache = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable `niri-flake`’s Cachix binary cache.

        The upstream module implements this as:
        - `niri-flake.cache.enable = true;`
        which adds:
        - substituter: https://niri.cachix.org
        - trusted key: niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=

        If you strictly control `nix.settings.substituters/trusted-public-keys` elsewhere,
        set this to `false` and manage caches yourself.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Niri using the upstream module’s standard option namespace.
    programs.niri = {
      enable = true;

      # Pin the package to the selected channel so you can easily switch between
      # stable/unstable without hunting for attribute names elsewhere.
      package = chosenPackage;
    };

    # Mirror/cache toggle for upstream: safe for most setups, but optional.
    niri-flake.cache.enable = lib.mkDefault cfg.enableCache;

    # NOTE: We intentionally do NOT disable/override Hydenix/HyDE or Hyprland here.
    # This module’s job is to add Niri “alongside” your existing desktop so you
    # can select it at login (the upstream module registers a session package).
    #
    # If you later want to make Niri your primary session, do that explicitly
    # in your display manager config rather than hiding it here.
  };
}
