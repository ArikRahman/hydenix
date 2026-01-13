{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  # NOTE: Disabled per request: arik's disk daemon/permission fix.
  # username = config.home.username;
  # mountPath = "/run/media/${username}/arik_s disk";
  # fixAriksDiskPerms = pkgs.writeShellScript "fix-ariks-disk-perms" ''
  #   set -euo pipefail
  #
  #   p="${mountPath}"
  #   if [ ! -d "$p" ]; then
  #     exit 0
  #   fi
  #   if ! ${pkgs.util-linux}/bin/mountpoint -q "$p"; then
  #     exit 0
  #   fi
  #
  #   # Ensure the mount root is traversable/readable/writable for this user.
  #   ${pkgs.acl}/bin/setfacl -m "u:${username}:rwx" "$p"
  #   ${pkgs.acl}/bin/setfacl -m "d:u:${username}:rwx" "$p"
  # '';
  #
  # NOTE (mistake & correction):
  # I initially tried to "just enable Doom" without wiring it to XDG + an Emacs daemon.
  # Doom works best when its directories are explicit and stable, so we declare the
  # XDG-based env vars and enable `services.emacs` below.

  # Doom Emacs private config
  #
  # Why:
  # - You want the private Doom config to live *under* `modules/hm` so it’s guaranteed to be
  #   included in the flake source and can be referenced reliably.
  #
  # NOTE (mistake & correction):
  # - I previously placed `.doom.d` at the repo root and referenced it via `../../.doom.d`.
  #   That can break depending on what gets copied into the flake source during evaluation.
  # - Fix: move the Doom private dir under `modules/hm` and reference it via `./.doom.d`.
  doomPrivateDir = ./doom.d;
in

let
  extension = shortId: guid: {
    name = guid;
    value = {
      install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
      installation_mode = "normal_installed";
    };
  };

  prefs = {
    "extensions.autoDisableScopes" = 0;
    "extensions.pocket.enabled" = false;
  };

  extensions = [
    (extension "ublock-origin" "uBlock0@raymondhill.net")
    (extension "bitwarden-password-manager" "{446900e4-71c2-419f-a6a7-df9c091e268b}")
    (extension "darkreader" "addon@darkreader.org")
    (extension "private-grammar-checker-harper" "harper@writewithharper.com")
    (extension "youtube-recommended-videos" "myallychou@gmail.com")
  ];

  zenWrapped =
    pkgs.wrapFirefox
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.zen-browser-unwrapped
      {
        extraPrefs = lib.concatLines (
          lib.mapAttrsToList (
            name: value: ''lockPref(${lib.strings.toJSON name}, ${lib.strings.toJSON value});''
          ) prefs
        );

        extraPolicies = {
          DisableTelemetry = true;
          ExtensionSettings = builtins.listToAttrs extensions;

          # Custom search engines (Firefox/Zen enterprise policies).

          #

          # NOTE:

          # - This config is modeled after the reference `configuration.nix` you shared.

          # - These show up as selectable search engines; `Default` sets the default.

          # - Brave here refers to **Brave Search**, not the Brave browser.

          SearchEngines = {

            Default = "Brave Search";

            Add = [

              {

                Name = "Brave Search";

                URLTemplate = "https://search.brave.com/search?q={searchTerms}";

                IconURL = "https://search.brave.com/favicon.ico";

                Alias = "@bs";

              }

              {

                Name = "nixpkgs packages";

                URLTemplate = "https://search.nixos.org/packages?query={searchTerms}";

                IconURL = "https://wiki.nixos.org/favicon.ico";

                Alias = "@np";

              }

              {

                Name = "NixOS options";

                URLTemplate = "https://search.nixos.org/options?query={searchTerms}";

                IconURL = "https://wiki.nixos.org/favicon.ico";

                Alias = "@no";

              }

              {

                Name = "NixOS Wiki";

                URLTemplate = "https://wiki.nixos.org/w/index.php?search={searchTerms}";

                IconURL = "https://wiki.nixos.org/favicon.ico";

                Alias = "@nw";

              }

              {

                Name = "noogle";

                URLTemplate = "https://noogle.dev/q?term={searchTerms}";

                IconURL = "https://noogle.dev/favicon.ico";

                Alias = "@ng";

              }

            ];

          };
        };
      };

  # NOTE: Disabled per request to remove hyprsunset from this repo.
  #
  # hyprsunsetctl = pkgs.writeShellScriptBin "hyprsunsetctl" ''
  #   set -euo pipefail
  #
  #   uid="$(id -u)"
  #   base="''${XDG_RUNTIME_DIR:-/run/user/$uid}/hypr"
  #   hyprctl_bin="${pkgs.hyprland}/bin/hyprctl"
  #
  #   if [ ! -d "$base" ]; then
  #     echo "hyprsunsetctl: expected Hyprland runtime dir at: $base" >&2
  #     exit 1
  #   fi
  #
  #   # Prefer the current shell's instance if it exists.
  #   sig=""
  #   if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE-}" ] && [ -S "$base/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket.sock" ]; then
  #     sig="''${HYPRLAND_INSTANCE_SIGNATURE}"
  #   else
  #     # Otherwise, probe candidates (newest first) until one responds.
  #     while IFS= read -r d; do
  #       [ -n "$d" ] || continue
  #       csig="$(basename "$d")"
  #       if HYPRLAND_INSTANCE_SIGNATURE="$csig" "$hyprctl_bin" -j monitors >/dev/null 2>&1; then
  #         sig="$csig"
  #         break
  #       fi
  #     done < <(
  #       for d in "$base"/*; do
  #         [ -S "$d/.socket.sock" ] || continue
  #         echo "$(stat -c '%Y %n' "$d")"
  #       done | sort -nr | awk '{print $2}'
  #     )
  #   fi
  #
  #   if [ -z "${"sig:-"}" ]; then
  #     echo "hyprsunsetctl: couldn't find a Hyprland instance socket in: $base" >&2
  #     exit 1
  #   fi
  #
  #   export HYPRLAND_INSTANCE_SIGNATURE="$sig"
  #   exec "$hyprctl_bin" hyprsunset "$@"
  # '';

  # Hydenix theme selection
  #
  # IMPORTANT: `SUPER + SHIFT + T` changes the theme at runtime, but Hydenix will
  # revert to whatever is configured in Nix on the next rebuild/relog/reboot.
  # Set this to the exact theme name shown by the theme picker to make it
  # persist across `nixos-rebuild`.
  desiredTheme = "Catppuccin Mocha";
in
{
  imports = [
    # ./example.nix - add your modules here

    # DankMaterialShell upstream Home Manager module (provides `programs.dank-material-shell.*`)
    inputs.dms.homeModules.dank-material-shell

    # DankMaterialShell Niri integration module (provides `programs.dank-material-shell.niri.*`)
    #
    # Why:
    # - Without this import, the `programs.dank-material-shell.niri` option set does not exist,
    #   and your HM evaluation fails when you try to enable DMS-provided Niri keybind injection.
    inputs.dms.homeModules.niri

    # Keep HyDE state dirs (themes, wallbash cache, waybar styles, etc.) mutable/local,
    # while still letting Nix/Home Manager manage the actual config files (ex: config.toml).
    ./overrides/hyde-local-state.nix
  ];

  # NOTE: Disabled per request: arik's disk daemon/permission fix.
  # systemd.user.paths.fix-ariks-disk-perms = {
  #   Unit = {
  #     Description = "Fix permissions for arik's disk when mounted";
  #   };
  #   Path = {
  #     PathExists = mountPath;
  #     Unit = "fix-ariks-disk-perms.service";
  #   };
  #   Install = {
  #     WantedBy = [ "default.target" ];
  #   };
  # };
  #
  # systemd.user.services.fix-ariks-disk-perms = {
  #   Unit = {
  #     Description = "Ensure arik's disk is accessible to the user";
  #   };
  #   Service = {
  #     Type = "oneshot";
  #     ExecStart = fixAriksDiskPerms;
  #   };
  # };

  # home-manager options go here
  home.packages = with pkgs; [
    zenWrapped

    brave
    signal-desktop
    # dorion
    syncthing
    cachix

    blesh
    localsend

    #inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

    #Applications
    ayugram-desktop
    boxflat
    swaybg
    spacedrive
    neohtop
    nautilus
    obsidian
    qbittorrent
    legcord
    reaper
    logseq
    obs-studio
    webex

    seahorse

    #Terminal tools
    curl
    unzip
    wget
    atool
    httpie
    discordo # terminal discord
    blesh # oh my bash
    fzf
    dust
    sqlite
    yq # yaml processor and json as well
    lazygit
    ripgrep-all # rga, ripgrep with extra file format support
    gh
    just
    bottom # rust based top
    zenith # more traditional top based on rust
    nvd # useful for seeing difference in nix generations. syntax e.g.
    # ```nvd diff /nix/var/nix/profiles/system-31-link /nix/var/nix/profiles/system-30-link```
    gdb # for debugging

    #LSP and language tooling
    clojure-lsp
    nil
    nixd

    ripgrep-all
    zellij

    clojure
    clojure-lsp
    babashka
    jdk25 # LTS until 2031
    nil
    nixd
    ruff
    gh

    marksman
    ruff # python rust based

    zellij

    #Language
    babashka
    clojure
    clojure-lsp

    # Rust toolchain (nixpkgs method; pinned by your flake input)
    #
    # Why:
    # - The NixOS Rust wiki recommends installing via nixpkgs for simplicity + determinism.
    # - This provides a stable toolchain suitable for most Rust development without rustup.
    #
    # Includes:
    # - `rustc` + `cargo` for compiling/building
    # - `rustfmt` + `clippy` for formatting/linting
    # - `rust-analyzer` for editor LSP
    #
    # NOTE:
    # - Some editor setups need rust source (`RUST_SRC_PATH`) to be set; handled via
    #   `home.sessionVariables.RUST_SRC_PATH` below.
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer

    # C/FFI helpers commonly needed by Rust crates (bindgen, openssl-sys, etc.)
    #
    # Why:
    # - The NixOS Rust wiki notes that crates using `bindgen` and crates that link against
    #   system libs often need:
    #   - `pkg-config` to locate libraries
    #   - a C compiler / libc headers (provided by `clang` in typical setups)
    #
    # NOTE:
    # - You may still need to add specific libs (e.g. `openssl`, `sqlite`) per-project.
    # - Keeping these here helps with the common “linking with cc failed” class of errors.
    pkg-config
    clang

    uv
    nim

    jdk25 # jvm will outperform graalvm AOT with implementation of project leydus
    # graalvmPackages.graalvm-ce

    pandoc
    protontricks

    curl
    wget
    unzip
    pandoc # document converter

    protontricks

    # Preferred over screen shaders: hyprsunset uses Hyprland's CTM control,
    # so the filter won't show up in screenshots / recordings.
    #
    # NOTE: Disabled per request to remove hyprsunset from this repo.
    # hyprsunset
    # hyprsunsetctl
    # pkgs.vscode - hydenix's vscode version
    # pkgs.userPkgs.vscode - your personal nixpkgs version

    # Niri tooling
    alacritty
    fuzzel
    # NOTE: Noctalia removed; replaced by DankMaterialShell (DMS) via upstream HM module.
    swaybg
  ];

  # Niri + DankMaterialShell (Home Manager managed)
  #
  # Why:
  # - Replace Noctalia with DankMaterialShell (DMS).
  # - Niri doesn't have an official "shell" concept like GNOME; the practical
  #   equivalent is to run your shell UI as a user service inside the session.
  #
  # Implementation:
  # - Use the upstream DMS Home Manager module (`programs.dank-material-shell.*`)
  #   which provides a user systemd service (`dms`) when `systemd.enable = true`.
  #
  # Note:
  # - This enables Niri via Home Manager. It does not register a login-session
  #   entry in SDDM by itself.
  programs.niri = {
    # NOTE (mistake & correction):
    # I initially enabled Niri from Home Manager (`programs.niri.enable = true`).
    # In your setup, the Niri option set comes from the system-side `niri-flake`
    # module wiring, so enabling/disabling the compositor belongs on the NixOS side.
    #
    # Fix: keep HM in charge of *configuration* (settings) and user services, but
    # do not toggle Niri's NixOS enablement from Home Manager.
    #
    # enable = true;

    # NOTE:
    # If your option set includes `programs.niri.package`, you can pin it here.
    # I'm commenting this out to avoid option/namespace mismatches across module wiring.
    #
    # package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-stable;

    # Minimal starter config + core compositor keybinds. Extend as you like.
    settings = {
      # Helpful for Electron apps under Wayland.
      environment."NIXOS_OZONE_WL" = "1";

      # Core Niri compositor keybinds (v25.08).
      #
      # NOTE (mistake & correction):
      # What I got wrong:
      # - I initially set `.action` to plain strings, but in `niri-flake` the option type
      #   is `niri action`, represented as an attrset with a single key (the action name)
      #   and a value that is its argument list (or a single arg).
      # How I corrected it:
      # - Use the documented schema: `"KEY".action.<action-name> = <args>;`
      #   (see `sodiboo/niri-flake` docs: `programs.niri.settings.binds.<name>.action`).
      #
      # Why these binds:
      # - DMS injects keybinds for *DMS features* (launcher, notifications, etc.) but not
      #   core compositor actions (quit, close, focus/move columns, workspace up/down, overview).
      #
      binds = {
        # Show Important Hotkeys
        "Super+Slash".action.show-hotkey-overlay = [ ];

        # Exit niri
        "Super+Shift+E".action.quit = [ ];

        # Close Focused Window
        "Super+Q".action.close-window = [ ];

        # Focus Column to the Left/Right
        "Super+Left".action.focus-column-left = [ ];
        "Super+Right".action.focus-column-right = [ ];

        # Move Column Left/Right
        "Super+Shift+Left".action.move-column-left = [ ];
        "Super+Shift+Right".action.move-column-right = [ ];

        # Switch Workspace Down/Up
        "Super+Ctrl+J".action.focus-workspace-down = [ ];
        "Super+Ctrl+K".action.focus-workspace-up = [ ];

        # Move Column to Workspace Down/Up
        "Super+Ctrl+Shift+J".action.move-column-to-workspace-down = [ ];
        "Super+Ctrl+Shift+K".action.move-column-to-workspace-up = [ ];

        # Switch Preset Column Widths
        "Super+R".action.switch-preset-column-width = [ ];

        # Maximize Column
        "Super+F".action.maximize-column = [ ];

        # Consume or Expel Window Left/Right
        "Super+BracketLeft".action.consume-or-expel-window-left = [ ];
        "Super+BracketRight".action.consume-or-expel-window-right = [ ];

        # Move Window Between Floating and Tiling
        "Super+Shift+Space".action.toggle-window-floating = [ ];

        # Switch Focus Between Floating and Tiling
        "Super+Tab".action.switch-focus-between-floating-and-tiling = [ ];

        # Open the Overview
        "Super+O".action.toggle-overview = [ ];

        # Screenshots (native Niri)
        #
        # Why:
        # - `Print` wasn't doing anything because there was no bind.
        # - Niri ships built-in screenshot actions and an interactive UI, so we prefer that
        #   over external tools (grim/slurp).
        #
        # Notes:
        # - Niri screenshots are copied to the clipboard by default.
        # - If you want to also save to disk via `screenshot-path`, we can add that once
        #   we confirm the exact schema exposed by your `niri-flake` module.
        "Print".action.screenshot = [ ];
        "Super+Print".action.screenshot-screen = [ ];
        "Shift+Print".action.screenshot-window = [ ];
      };
    };
  };

  # Start DankMaterialShell (DMS) automatically in your graphical session.
  #
  # Why:
  # - Make DMS behave like the "shell" layer when you use Niri (and other Wayland
  #   sessions too).
  #
  # If you only want it under Niri specifically:
  # - we can refine `WantedBy`/`PartOf` to bind to a Niri-specific target, but that
  #   depends on how your session is started (and whether a stable `niri.service`
  #   exists in your user unit graph).
  # NOTE: Noctalia autostart disabled; replaced by DankMaterialShell (DMS).
  #
  # What I got wrong earlier:
  # - I treated "shell autostart" as something we needed to hand-roll for every shell.
  # How I corrected it:
  # - DMS provides an upstream Home Manager module that includes a `dms` user service,
  #   so we enable that instead of maintaining our own unit here.
  #
  # systemd.user.services.noctalia-shell = {
  #   Unit = {
  #     Description = "Noctalia Shell (user)";
  #     PartOf = [ "graphical-session.target" ];
  #     After = [ "graphical-session.target" ];
  #   };
  #
  #   Service = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.noctalia-shell}/bin/noctalia-shell";
  #     Restart = "on-failure";
  #     RestartSec = 2;
  #
  #     # Small hardening baseline (optional, safe defaults for user services).
  #     NoNewPrivileges = true;
  #     PrivateTmp = true;
  #   };
  #
  #   Install = {
  #     WantedBy = [ "graphical-session.target" ];
  #   };
  # };

  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    settings = {
      background-opacity = "0.9";
      theme = desiredTheme;
    };
  };

  programs.yazi.enable = true;

  # Git config is managed declaratively to avoid tools (like `gh`) trying to write to
  # a read-only/symlinked config (common when Home Manager manages XDG paths).
  #
  # NOTE (mistake & correction):
  # I initially set `programs.git.userName` / `programs.git.userEmail` here, but Hydenix
  # already defines `programs.git.settings.user.email = false` in its own git module.
  # That produced a type conflict (string vs false). To stop conflicting with Hydenix,
  # we only configure the GitHub URL rewrite here and let Hydenix (or you) own identity.
  programs.git = {
    enable = true;

    # Intentionally NOT setting `userName` / `userEmail` here to avoid conflicting with Hydenix.

    # NOTE (mistake & correction):
    # Home Manager renamed `programs.git.extraConfig` to `programs.git.settings`.
    # Updating to the new option removes evaluation warnings.
    settings = {
      # Prefer HTTPS for GitHub (matches `gh`'s recommended default).
      url."https://github.com/".insteadOf = [
        "git@github.com:"
        "ssh://git@github.com/"
      ];

      # Optional: keep the default branch consistent with GitHub UI.
      init.defaultBranch = "main";
    };
  };

  programs.bash = {
    enable = true;
    bashrcExtra = ''
      # Only attach ble.sh in *real* interactive terminals.
      # This avoids spurious job-control noise like:
      #   bash: fg: current: no such job
      #   [ble: exit 1]
      #
      # We require:
      # - interactive shell ($- contains i)
      # - a real TTY on stdin/stdout
      # - not running inside a dumb terminal
      if [[ $- == *i* ]] && [[ -t 0 ]] && [[ -t 1 ]] && [[ ''${TERM:-} != dumb ]]; then
        source -- "$(blesh-share)"/ble.sh --attach=none
        [[ ! ''${BLE_VERSION-} ]] || ble-attach
      fi
    '';
  };

  programs.atuin = {
    enable = true;
    settings = {
      search_mode = "fuzzy";
    };
  };

  programs.zed-editor = {
    enable = true;
    userSettings = {
      theme = desiredTheme; # must match an installed Zed theme name
      ui_font_size = 16;
      buffer_font_size = 14;
      terminal = {
        shell = {
          with_arguments = {
            program = "nu";
            args = [ "-i" ];
          };
        };
      };
      # Add Nix language support extension for syntax highlighting and features
      extensions = [ "zed-industries.extensions.nix" ];
    };
  };

  programs.vscode = {
    enable = false;
    package = pkgs.vscode.overrideAttrs (oldAttrs: {
      postFixup = (oldAttrs.postFixup or "") + ''
        wrapProgram $out/bin/code --add-flags "--password-store=gnome-libsecret"
      '';
    });

    # NOTE: Home Manager renamed:
    # - `programs.vscode.extensions`   -> `programs.vscode.profiles.default.extensions`
    # - `programs.vscode.userSettings` -> `programs.vscode.profiles.default.userSettings`

    # NOTE (mistake & correction):
    # Home Manager renamed:
    # - `programs.vscode.extensions` -> `programs.vscode.profiles.default.extensions`
    # - `programs.vscode.userSettings` -> `programs.vscode.profiles.default.userSettings`
    # Updating to the new option names removes evaluation warnings.

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        catppuccin.catppuccin-vsc
        jnoortheen.nix-ide
      ];

      userSettings = {
        "workbench.colorTheme" = desiredTheme;
      };
    };
  };

  programs.nushell = {
    enable = true;

    # Use config.nu from this same directory (next to home.nix)
    configFile.source = ./config.nu; # Home Manager supports configFile.source for Nushell. [web:1][web:17]
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
  };

  services.gnome-keyring = {
    enable = true;
    components = [
      "pkcs11"
      "secrets"
      "ssh"
    ];
  };

  # Make Zen the default browser (xdg-open, portals, file managers)
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http" = [ "zen.desktop" ];
    "x-scheme-handler/https" = [ "zen.desktop" ];
    "text/html" = [ "zen.desktop" ];
    "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
  };

  ############################
  # Doom Emacs (XDG layout) + Emacs daemon
  ############################
  #
  # Why:
  # - Mirrors the reference setup: Doom + private config in XDG locations.
  # - Enables an Emacs daemon so `emacsclient` is instant and GUI frames work reliably in Wayland sessions.
  #
  # NOTE:
  # - This assumes your flake already imports `inputs.nix-doom-emacs-unstraightened.homeModule`.
  #   If it doesn't, evaluation will fail because `programs.doom-emacs` won't exist. In that case,
  #   the correct fix is to add that import at the flake/home-manager wiring level.
  xdg.enable = true;

  # NOTE (mistake & correction):
  # I originally added a second `home.sessionVariables = { ... };` assignment for Doom.
  # Home Manager treats that as a duplicate definition because this file already sets
  # `home.sessionVariables.<NAME> = ...` elsewhere.
  #
  # Fix: define Doom variables using the attribute form (`home.sessionVariables.<NAME>`)
  # so they merge cleanly with the existing assignments.
  home.sessionVariables.EMACSDIR = "${config.xdg.configHome}/emacs";
  home.sessionVariables.DOOMDIR = "${config.xdg.configHome}/doom";
  home.sessionVariables.DOOMLOCALDIR = "${config.xdg.dataHome}/doom";
  home.sessionVariables.DOOMPROFILELOADFILE = "${config.xdg.configHome}/doom/profiles.el";

  # Rust tooling support
  #
  # Why:
  # - The NixOS Rust wiki notes some tools (notably certain rust-analyzer setups)
  #   require access to the Rust stdlib source via `RUST_SRC_PATH`.
  # - `rustPlatform.rustLibSrc` points at the correct lib source path in nixpkgs.
  #
  # NOTE:
  # - If you explicitly use rust-analyzer from nixpkgs (as you do above), many setups
  #   won’t need this, but it’s a harmless compatibility improvement and makes
  #   editor configuration more reliable.
  home.sessionVariables.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

  # NOTE (mistake & correction):
  # I previously referenced `config.home.sessionPath` while defining `home.sessionPath`,
  # which can cause infinite recursion in Home Manager's module system.
  #
  # Fix: define `home.sessionPath` directly (HM will merge lists from multiple modules).
  home.sessionPath = [
    "${config.xdg.configHome}/emacs/bin"
  ];

  programs.doom-emacs = {
    enable = true;
    doomDir = doomPrivateDir;
  };

  # Put Doom + config in XDG
  #
  # Why:
  # - Matches your reference: `~/.config/emacs` points at the pinned upstream Doom repo,
  #   and `~/.config/doom` points at your private Doom config.
  #
  # NOTE (mistake & correction):
  # - I previously only sourced the private Doom dir, which meant the upstream Doom repo
  #   was not being staged into XDG and you wouldn't get the same “Doom installed via XDG”
  #   behavior as the reference.
  #
  # Requirements:
  # - Your flake must provide `inputs.doomemacs` (added in `dotfiles/flake.nix`).
  xdg.configFile."emacs".source = inputs.doomemacs;
  xdg.configFile."doom".source = doomPrivateDir;

  services.emacs = {
    enable = true;

    # Helps avoid “daemon started too early” issues for GUI frames.
    startWithUserSession = "graphical";

    # NOTE (mistake & correction):
    # I previously set `defaultEditor = true;`, which makes Home Manager set `$EDITOR`
    # to an Emacs derivation. Hydenix already sets `$EDITOR` (ex: "code"), so this
    # created a type conflict (string vs derivation) during evaluation.
    #
    # Fix: disable Emacs taking over `$EDITOR` and set it explicitly below.
    defaultEditor = false;

    # IMPORTANT:
    # Prefer the Emacs package produced by the Doom module when available.
    # If this option is absent in your module version, comment it back out.
    # package = config.programs.doom-emacs.package;
  };

  # Optional: some CLI tools consult $BROWSER.
  #
  # Editor:
  # - Keep this a plain string (not a derivation) to avoid HM type conflicts.
  # - You asked to use Zed.
  home.sessionVariables.EDITOR = lib.mkForce "zed";

  home.sessionVariables.BROWSER = "zen";
  home.sessionVariables.FILEMANAGER = "nautilus";

  # Default terminal preference.
  # HyDE commonly launches terminals via `xdg-terminal-exec`, which consults
  # `xdg-terminals.list` preference files. Putting Ghostty first makes
  # terminal keybinds/launchers prefer it without uninstalling Kitty.
  #
  # NOTE (mistake & correction):
  # I initially treated this as a simple "default terminal" preference issue.
  # That does not override a hardcoded Hyprland keybind that explicitly runs `kitty`.
  # The correct fix is to also define/override the Hyprland keybind source-of-truth
  # via Hydenix's Hyprland keybindings module (below).
  home.sessionVariables.TERMINAL = "ghostty";

  # Hyprland keybind override (HyDE):
  # Force `SUPER + T` to launch Ghostty instead of Kitty, regardless of HyDE defaults.
  #
  # Rationale: Some HyDE configs hardcode `kitty` in the terminal keybind.
  # Managing it here makes the behavior reproducible across rebuilds.
  hydenix.hm.hyprland.keybindings.extraConfig = ''
    # Terminal: Ghostty
    #
    # NOTE (mistake & correction):
    # I previously added a second `SUPER + T` bind which caused *both* actions to
    # trigger (HyDE's default kitty bind + this ghostty bind).
    #
    # Hyprland doesn't have an "unbind" directive for prior binds in included
    # configs, but it *does* support consuming the key with a `pass` bind.
    # We consume `SUPER + T` first so the earlier kitty bind won't run, then we
    # re-bind it to Ghostty.
    #
    # If you still see both terminals, it means HyDE loads another bind *after*
    # this extraConfig; in that case, switch this from `extraConfig` to
    # `overrideConfig` in the Hydenix Hyprland module implementation.
    bind = SUPER, T, pass
    bind = SUPER, T, exec, ghostty
  '';

  # Preferred terminal list for xdg-terminal-exec (Default Terminal spec impl).
  # This file is read from `$XDG_CONFIG_HOME/xdg-terminal-exec/xdg-terminals.list`.
  xdg.configFile."xdg-terminal-exec/xdg-terminals.list".text = ''
    ghostty
    kitty
  '';

  # NOTE (mistake & correction): I initially also managed `.config/xdg-terminals.list`.
  # Hydenix already manages that target, so Home Manager raised a conflict.
  # The fix is to only manage the `xdg-terminal-exec` preference file here.

  # hydenix home-manager options go here
  hydenix.hm.enable = true;
  hydenix.hm.dolphin.enable = false;

  # DankMaterialShell (DMS)
  #
  # Why:
  # - Replace Noctalia with DMS.
  # - Let the upstream module manage packages + a robust user systemd unit.
  programs.dank-material-shell = {
    enable = true;

    # NOTE: Prefer starting DMS via Niri spawn integration (single source of autostart),
    # so you don't get duplicate DMS instances from both systemd + compositor startup.
    #
    # If you later want DMS available in non-Niri Wayland sessions too, flip this back on
    # (and likely set `niri.enableSpawn = false;` to keep it single-start).
    systemd.enable = false;

    # Niri integration
    #
    # Why:
    # - Your `niri validate` error shows `include "..."` nodes at the top of the generated
    #   Niri config. That means DMS is currently emitting Niri `include` statements, but
    #   your installed Niri build does not support the `include` node.
    #
    # Fix:
    # - Disable DMS "includes" feature so the generated Niri config is self-contained
    #   (no `include` nodes), while still keeping DMS keybind/spawn integration enabled.
    niri = {
      enableKeybinds = true;
      enableSpawn = true;

      # DMS Niri integration: keep the generated config self-contained because
      # your `niri validate` showed `include "..."` is not supported by your Niri build.
      includes.enable = false;

      # Minimal Niri default keybind set (core compositor actions).
      #
      # NOTE (mistake & correction):
      # What I got wrong:
      # - I attempted to configure `programs.dank-material-shell.niri.keybinds = { ... }`,
      #   but your installed DMS module does not expose that option set (it failed `nix flake check`).
      # How I corrected it:
      # - I’m commenting this block back out to restore a valid evaluation.
      #
      # Guidance (next step):
      # - To bind the core Niri compositor actions (exit, close, focus left/right, workspace up/down, overview, etc.),
      #   implement them via `programs.niri.settings` once we confirm the exact schema your Niri module expects.
      #
      # keybinds = {
      #   enable = true;
      #
      #   # Use "Super" as the primary modifier.
      #   mod = "Super";
      #
      #   # System / session
      #   showHotkeys = "Super+Slash"; # Show Important Hotkeys
      #   exit = "Super+Shift+E"; # Exit niri
      #   closeWindow = "Super+Shift+Q"; # Close Focused Window
      #
      #   # Focus columns
      #   focusLeft = "Super+H"; # Focus Column to the Left
      #   focusRight = "Super+L"; # Focus Column to the Right
      #
      #   # Move columns
      #   moveLeft = "Super+Shift+H"; # Move Column Left
      #   moveRight = "Super+Shift+L"; # Move Column Right
      #
      #   # Workspaces (relative)
      #   workspaceDown = "Super+Ctrl+J"; # Switch Workspace Down
      #   workspaceUp = "Super+Ctrl+K"; # Switch Workspace Up
      #   moveToWorkspaceDown = "Super+Ctrl+Shift+J"; # Move Column to Workspace Down
      #   moveToWorkspaceUp = "Super+Ctrl+Shift+K"; # Move Column to Workspace Up
      #
      #   # Layout / sizing
      #   cyclePresetWidths = "Super+R"; # Switch Preset Column Widths
      #   maximizeColumn = "Super+F"; # Maximize Column
      #
      #   # Column consume/expel (swap/absorb semantics)
      #   consumeOrExpelLeft = "Super+BracketLeft"; # Consume or Expel Window Left
      #   consumeOrExpelRight = "Super+BracketRight"; # Consume or Expel Window Right
      #
      #   # Floating/tiling
      #   toggleFloating = "Super+Shift+Space"; # Move Window Between Floating and Tiling
      #   focusFloatingTiling = "Super+Tab"; # Switch Focus Between Floating and Tiling
      #
      #   # Overview
      #   overview = "Super+O"; # Open the Overview
      # };
    };
  };

  # This is the setting Hydenix uses as the source-of-truth on rebuild.
  hydenix.hm.theme.active = desiredTheme;

  # Prefer hyprsunset over Hyprland screen shaders so the effect isn't captured
  # by screenshots / recordings.
  #
  # NOTE: Disabled per request to remove hyprsunset from this repo.
  # hydenix.hm.hyprland.shaders.active = "disable";

  # hyprsunset configuration (~/.config/hypr/hyprsunset.conf)
  # NOTE: Disabled per request to remove hyprsunset from this repo.
  # xdg.configFile."hypr/hyprsunset.conf".text = ''
  #   max-gamma = 150
  #
  #   profile {
  #       time = 7:30
  #       identity = true
  #   }
  #
  #   profile {
  #       time = 21:00
  #       temperature = 4500
  #       gamma = 1.0
  #   }
  # '';

  # Start hyprsunset automatically in the user session.
  # NOTE: Disabled per request to remove hyprsunset from this repo.
  # systemd.user.services.hyprsunset = {
  #   Unit = {
  #     Description = "Hyprsunset (night light)";
  #     PartOf = [ "graphical-session.target" ];
  #     After = [ "graphical-session.target" ];
  #   };
  #   Service = {
  #     ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset";
  #     Restart = "on-failure";
  #     RestartSec = 2;
  #   };
  #   Install = {
  #     WantedBy = [ "graphical-session.target" ];
  #   };
  # };

  # Hard-disable hyprsunset even if some upstream module (or a previous generation)
  # tries to enable it.
  #
  # Why: your journal shows `hyprsunset.service` repeatedly restarting and failing
  # under `niri` ("Compositor doesn't support hyprland-ctm-control-v1"). That means
  # something is still generating/enabling the user service (likely via Home Manager),
  # and systemd keeps auto-restarting it.
  #
  # NOTE (got wrong earlier): `systemd.user.services.<name>` in Home Manager expects
  # an *attribute set* describing the unit (Unit/Service/Install). It does *not* accept
  # `enable = false` here (that option is not the right shape in this module), which
  # causes evaluation to fail.
  #
  # This block defines an inert unit and does not install/want it anywhere, so it
  # won't be pulled into `graphical-session.target`.
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "Hyprsunset (night light) (disabled via Home Manager override)";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/true";
      RemainAfterExit = true;
    };

    Install = {
      WantedBy = [ ];
    };
  };

  hydenix.hm.hyprland.extraConfig = ''
    cursor {
        no_hardware_cursors = true
    }
    misc {
        allow_session_lock_restore = true
    }
  '';
  hydenix.hm.editors.vscode.enable = false;

  # NOTE (performance fix): Hydenix's theme module makes themes available by copying them
  # as "mutable home files" into `~/.config/hyde/themes/<ThemeName>` during the
  # `mutableFileGeneration` activation step. With many themes enabled, this turns into
  # multi-GB reads/writes (your run showed ~8G read / ~1.7G written) and a ~1m pause.
  #
  # Option B: Stop Home Manager from installing the entire theme package list.
  # We keep only the active theme name (via `hydenix.hm.theme.active`) and leave the
  # theme directory itself as runtime/local state (HyDE can manage it).
  #
  # NOTE (rule compliance): I am not deleting the old theme list; I am commenting it
  # out so you can restore it if you accept the activation-time I/O cost.
  hydenix.hm.theme.themes = [
    desiredTheme
  ];

  # hydenix.hm.theme.themes = [
  #   "1 Bit"
  #   "AbyssGreen"
  #   "Abyssal Wave"
  #   "Amethyst Aura"
  #   "AncientAliens"
  #   "Another World"
  #   "Bad Blood"
  #   "BlueSky"
  #   "Breezy Autumn"
  #   "Cat Latte"
  #   "Catppuccin Latte"
  #   "Catppuccin Macchiato"
  #   "Catppuccin Mocha"
  #   "Code Garden"
  #   "Cosmic Blue"
  #   "Crimson Blade"
  #   "Crimson Blue"
  #   "Decay Green"
  #   "DoomBringers"
  #   "Dracula"
  #   "Edge Runner"
  #   "Electra"
  #   "Eternal Arctic"
  #   "Ever Blushing"
  #   "Frosted Glass"
  #   "Graphite Mono"
  #   "Green Lush"
  #   "Greenify"
  #   "Grukai"
  #   "Gruvbox Retro"
  #   "Hack the Box"
  #   "Ice Age"
  #   "Joker"
  #   "LimeFrenzy"
  #   "Mac OS"
  #   "Material Sakura"
  #   "Monokai"
  #   "Monterey Frost"
  #   "Moonlight"
  #   "Nightbrew"
  #   "Nordic Blue"
  #   "Obsidian Purple"
  #   "One Dark"
  #   "Oxo Carbon"
  #   "Paranoid Sweet"
  #   "Peace Of Mind"
  #   "Pixel Dream"
  #   "Rain Dark"
  #   "Red Stone"
  #   "Rose Pine"
  #   "Scarlet Night"
  #   "Sci fi"
  #   "Solarized Dark"
  #   "Synth Wave"
  #   "Timeless Dream"
  #   "Tokyo Night"
  #   "Tundra"
  #   "Vanta Black"
  #   "Windows 11"
  # ];
  # Visit https://github.com/richen604/hydenix/blob/main/docs/options.md for more options
}
