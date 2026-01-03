{ inputs, pkgs, lib, ... }:

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
in
{
  imports = [
    # ./example.nix - add your modules here
  ];

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

    seahorse
    gh
    atool
    httpie
    discordo
    blesh
    fzf
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
      theme = "Catppuccin Mocha";
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
      theme = "Catppuccin Mocha"; # or Latte/Frappe/Macchiato depending on what the extension provides
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
  };

  # Optional: some CLI tools consult $BROWSER.
  home.sessionVariables.BROWSER = "zen";


  # hydenix home-manager options go here
  hydenix.hm.enable = true;
  # Visit https://github.com/richen604/hydenix/blob/main/docs/options.md for more options
}
