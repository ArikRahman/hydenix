{ inputs, pkgs, lib, config, ... }:

let
  username = config.home.username;
  mountPath = "/run/media/${username}/arik_s disk";
  fixAriksDiskPerms = pkgs.writeShellScript "fix-ariks-disk-perms" ''
    set -euo pipefail

    p="${mountPath}"
    if [ ! -d "$p" ]; then
      exit 0
    fi
    if ! ${pkgs.util-linux}/bin/mountpoint -q "$p"; then
      exit 0
    fi

    # Ensure the mount root is traversable/readable/writable for this user.
    ${pkgs.acl}/bin/setfacl -m "u:${username}:rwx" "$p"
    ${pkgs.acl}/bin/setfacl -m "d:u:${username}:rwx" "$p"
  '';

in

let
  extension = shortId: guid: {
    name = guid;
    value = {
      install_url =
        "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
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
  ];

  zenWrapped =
    pkgs.wrapFirefox
      inputs.zen-browser.packages.${pkgs.system}.zen-browser-unwrapped
      {
        extraPrefs = lib.concatLines (
          lib.mapAttrsToList (
            name: value:
              ''lockPref(${lib.strings.toJSON name}, ${lib.strings.toJSON value});''
          ) prefs
        );

        extraPolicies = {
          DisableTelemetry = true;
          ExtensionSettings = builtins.listToAttrs extensions;
        };
      };

  hyprsunsetctl = pkgs.writeShellScriptBin "hyprsunsetctl" ''
    set -euo pipefail

    uid="$(id -u)"
    base="''${XDG_RUNTIME_DIR:-/run/user/$uid}/hypr"
    hyprctl_bin="${pkgs.hyprland}/bin/hyprctl"

    if [ ! -d "$base" ]; then
      echo "hyprsunsetctl: expected Hyprland runtime dir at: $base" >&2
      exit 1
    fi

    # Prefer the current shell's instance if it exists.
    sig=""
    if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE-}" ] && [ -S "$base/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket.sock" ]; then
      sig="''${HYPRLAND_INSTANCE_SIGNATURE}"
    else
      # Otherwise, probe candidates (newest first) until one responds.
      while IFS= read -r d; do
        [ -n "$d" ] || continue
        csig="$(basename "$d")"
        if HYPRLAND_INSTANCE_SIGNATURE="$csig" "$hyprctl_bin" -j monitors >/dev/null 2>&1; then
          sig="$csig"
          break
        fi
      done < <(
        for d in "$base"/*; do
          [ -S "$d/.socket.sock" ] || continue
          echo "$(stat -c '%Y %n' "$d")"
        done | sort -nr | awk '{print $2}'
      )
    fi

    if [ -z "${sig:-}" ]; then
      echo "hyprsunsetctl: couldn't find a Hyprland instance socket in: $base" >&2
      exit 1
    fi

    export HYPRLAND_INSTANCE_SIGNATURE="$sig"
    exec "$hyprctl_bin" hyprsunset "$@"
  '';

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
  ];

  systemd.user.paths.fix-ariks-disk-perms = {
    Unit = {
      Description = "Fix permissions for arik's disk when mounted";
    };
    Path = {
      PathExists = mountPath;
      Unit = "fix-ariks-disk-perms.service";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.fix-ariks-disk-perms = {
    Unit = {
      Description = "Ensure arik's disk is accessible to the user";
    };
    Service = {
      Type = "oneshot";
      ExecStart = fixAriksDiskPerms;
    };
  };

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

    #inputs.zen-browser.packages.${pkgs.system}.default


    ayugram-desktop
    boxflat
    swaybg
    spacedrive
    neohtop
    nautilus
    obsidian

    seahorse
    gh
    atool
    httpie
    discordo
    blesh
    fzf

    # Preferred over screen shaders: hyprsunset uses Hyprland's CTM control,
    # so the filter won't show up in screenshots / recordings.
    hyprsunset
    hyprsunsetctl
    # pkgs.vscode - hydenix's vscode version
    # pkgs.userPkgs.vscode - your personal nixpkgs version
  ];

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


  programs.bash = {
    enable = true;
    bashrcExtra = ''
      [[ $- == *i* ]] && source -- "$(blesh-share)"/ble.sh --attach=none
      [[ ! ''${BLE_VERSION-} ]] || ble-attach
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
    };
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.overrideAttrs (oldAttrs: {
      postFixup = (oldAttrs.postFixup or "") + ''
        wrapProgram $out/bin/code --add-flags "--password-store=gnome-libsecret"
      '';
    });
    extensions = with pkgs.vscode-extensions; [
      catppuccin.catppuccin-vsc
      jnoortheen.nix-ide
    ];
    userSettings = {
      "workbench.colorTheme" = desiredTheme;
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
    components = [ "pkcs11" "secrets" "ssh" ];
  };


    # Make Zen the default browser (xdg-open, portals, file managers)
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http"  = [ "zen.desktop" ];
    "x-scheme-handler/https" = [ "zen.desktop" ];
    "text/html"              = [ "zen.desktop" ];
    "inode/directory"        = [ "org.gnome.Nautilus.desktop" ];
  };

  # Optional: some CLI tools consult $BROWSER.
  home.sessionVariables.BROWSER = "zen";
  home.sessionVariables.FILEMANAGER = "nautilus";


  # hydenix home-manager options go here
  hydenix.hm.enable = true;
  hydenix.hm.dolphin.enable = false;

  # This is the setting Hydenix uses as the source-of-truth on rebuild.
  hydenix.hm.theme.active = desiredTheme;

  # Prefer hyprsunset over Hyprland screen shaders so the effect isn't captured
  # by screenshots / recordings.
  hydenix.hm.hyprland.shaders.active = "disable";

  # hyprsunset configuration (~/.config/hypr/hyprsunset.conf)
  xdg.configFile."hypr/hyprsunset.conf".text = ''
    max-gamma = 150

    profile {
        time = 7:30
        identity = true
    }

    profile {
        time = 21:00
        temperature = 4500
        gamma = 1.0
    }
  '';

  # Start hyprsunset automatically in the user session.
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "Hyprsunset (night light)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
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
  hydenix.hm.theme.themes = [
    "1 Bit"
    "AbyssGreen"
    "Abyssal Wave"
    "Amethyst Aura"
    "AncientAliens"
    "Another World"
    "Bad Blood"
    "BlueSky"
    "Breezy Autumn"
    "Cat Latte"
    "Catppuccin Latte"
    "Catppuccin Macchiato"
    "Catppuccin Mocha"
    "Code Garden"
    "Cosmic Blue"
    "Crimson Blade"
    "Crimson Blue"
    "Decay Green"
    "DoomBringers"
    "Dracula"
    "Edge Runner"
    "Electra"
    "Eternal Arctic"
    "Ever Blushing"
    "Frosted Glass"
    "Graphite Mono"
    "Green Lush"
    "Greenify"
    "Grukai"
    "Gruvbox Retro"
    "Hack the Box"
    "Ice Age"
    "Joker"
    "LimeFrenzy"
    "Mac OS"
    "Material Sakura"
    "Monokai"
    "Monterey Frost"
    "Moonlight"
    "Nightbrew"
    "Nordic Blue"
    "Obsidian Purple"
    "One Dark"
    "Oxo Carbon"
    "Paranoid Sweet"
    "Peace Of Mind"
    "Pixel Dream"
    "Rain Dark"
    "Red Stone"
    "Rose Pine"
    "Scarlet Night"
    "Sci fi"
    "Solarized Dark"
    "Synth Wave"
    "Timeless Dream"
    "Tokyo Night"
    "Tundra"
    "Vanta Black"
    "Windows 11"
  ];
  # Visit https://github.com/richen604/hydenix/blob/main/docs/options.md for more options
}
