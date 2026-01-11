{
  inputs,
  pkgs,
  ...
}:
# FOLLOW THE BELOW INSTRUCTIONS LINE BY LINE TO SET UP YOUR SYSTEM
{
  # Home Manager backup behavior:
  #
  # NOTE (mistake & correction):
  # I previously added `home-manager.backupFileExtension` here at the top level, but that duplicates
  # the setting already defined inside the `home-manager = { ... }` block below, causing:
  #   "attribute 'home-manager.backupFileExtension' already defined"
  #
  # The correct approach is to keep a single setting in the `home-manager` block (as `backupFileExtension = ...;`)
  # and not define `home-manager.backupFileExtension` separately.
  # External Steam library disk (ext4 inside LUKS).
  #
  # Why this exists:
  # Steam/Proton failed with: `compatdata/.../pfx is not owned by you`
  # because the disk was being mounted in a way that made created files look
  # like they were owned by a different user (so Wine refuses to use them).
  #
  # Fix approach:
  # - Mount the filesystem declaratively via NixOS (not desktop automount),
  #   and set ownership/permissions explicitly after mount.
  #
  # NOTE (mistake & correction):
  # I first assumed this might be NTFS/exFAT (where uid/gid mount options matter),
  # but your `lsblk -f` shows ext4. For ext4, ownership is real on-disk, so we
  # ensure the mountpoint is owned correctly and keep permissions stable.
  imports = [
    # hydenix inputs - Required modules, don't modify unless you know what you're doing
    inputs.hydenix.inputs.home-manager.nixosModules.home-manager
    inputs.hydenix.nixosModules.default
    ./modules/system # Your custom system modules
    ./hardware-configuration.nix # Auto-generated hardware config

    # Hardware Configuration - Uncomment lines that match your hardware
    # Run `lshw -short` or `lspci` to identify your hardware

    # GPU Configuration (choose one):
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia # NVIDIA
    # inputs.nixos-hardware.nixosModules.common-gpu-amd # AMD

    # CPU Configuration (choose one):
    # inputs.nixos-hardware.nixosModules.common-cpu-amd # AMD CPUs
    inputs.nixos-hardware.nixosModules.common-cpu-intel # Intel CPUs

    # Additional Hardware Modules - Uncomment based on your system type:
    # inputs.nixos-hardware.nixosModules.common-hidpi # High-DPI displays
    inputs.nixos-hardware.nixosModules.common-pc-laptop # Laptops
    inputs.nixos-hardware.nixosModules.common-pc-ssd # SSD storage
  ];

  # If enabling NVIDIA, you will be prompted to configure hardware.nvidia
  # hardware.nvidia = {
  #   open = true; # For newer cards, you may want open drivers
  #   prime = { # For hybrid graphics (laptops), configure PRIME:
  #     amdBusId = "PCI:0:2:0"; # Run `lspci | grep VGA` to get correct bus IDs
  #     intelBusId = "PCI:0:2:0"; # if you have intel graphics
  #     nvidiaBusId = "PCI:1:0:0";
  #     offload.enable = false; # Or disable PRIME offloading if you don't care
  #   };
  # };

  # Enable NVIDIA suspend/resume reliability tweaks (Wayland/Hyprland black screen fix)
  #
  # Why:
  # - You reported: NVIDIA + Wayland + Hyprland, resume returns a black screen.
  # - TTY works (Ctrl+Alt+F3), which strongly indicates the OS is alive and the graphics
  #   resume path is failing.
  # - The dedicated module `modules/system/nvidia-sleep-fix.nix` wires NVIDIA modesetting
  #   + sleep integration; this toggle turns it on.
  hydenix.system.nvidiaSleepFix.enable = true;

  # RTX 3050 (Ampere) note:
  # - NixOS requires explicitly choosing open vs closed NVIDIA kernel modules on driver >= 560.
  # - For Turing or later GPUs (RTX series, GTX 16xx), NixOS suggests using the open kernel modules.
  # - Your GPU is an RTX 3050, so we choose the open kernel modules.
  #
  # Implementation detail:
  # - The sleep/resume module sets a conservative default (`open = false`) for broad compatibility.
  # - This host-level override is the explicit, intentional choice for your RTX 3050.
  hardware.nvidia.open = true;

  # NOTE: Leave these off unless you specifically confirm they help.
  # - `restartDisplayManagerOnResume` is a workaround that can kill your session.
  # - `forceDeepSleep` is hardware-dependent (s2idle vs deep).
  # hydenix.system.nvidiaSleepFix.restartDisplayManagerOnResume = true;
  # hydenix.system.nvidiaSleepFix.forceDeepSleep = true;

  # Niri (Wayland compositor) — optional, installed alongside Hyprland/HyDE
  #
  # Why:
  # - Adds the Niri session + required plumbing via `sodiboo/niri-flake` when enabled.
  # - Does NOT change your default session; you can select Niri at login (SDDM) when you want.
  #
  # How:
  # - This toggle is defined by `./modules/system/niri.nix` and wires into `programs.niri.*`.
  #
  # NOTE: keep this `false` until you’re ready to try it.
  hydenix.system.niri.enable = true;
  # Optional knobs:
  hydenix.system.niri.channel = "stable"; # or "unstable", but use stable for cachix'd binary (low compile time)
  hydenix.system.niri.enableCache = true; # enable niri.cachix.org via upstream module

  # Home Manager Configuration - manages user-specific configurations (dotfiles, themes, etc.)
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup-2026_01_11-00_11_59";
    extraSpecialArgs = { inherit inputs; };
    # User Configuration - REQUIRED: Change "hydenix" to your actual username
    # This must match the username you define in users.users below
    users."hydenix" =
      { ... }:
      {
        imports = [
          inputs.hydenix.homeModules.default
          ./modules/hm # Your custom home-manager modules (configure hydenix.hm here!)
        ];
      };
  };

  # Mount the external ext4 volume (arik's disk) in a stable location, managed by NixOS.
  #
  # IMPORTANT:
  # - We intentionally use `/mnt/arik_s_disk` (no spaces) to avoid path edge-cases with tools.
  # - Your Steam library can be moved to `/mnt/arik_s_disk/SteamLibrary`.
  #
  # References from your `lsblk -f`:
  # - LUKS UUID: 72a8054a-d009-430c-9b0f-1cd570933865
  # - Inner ext4 UUID (label "arik's disk"): d87233ac-1c17-4f0d-9304-c4b28315667b
  #
  # NOTE:
  # If you already have manual/desktop automount at `/run/media/...`, this will replace it
  # for your workflow (use the new path in Steam).
  fileSystems."/mnt/arik_s_disk" = {
    device = "/dev/disk/by-uuid/d87233ac-1c17-4f0d-9304-c4b28315667b";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=1min"

      # Steam/Proton runtime fix:
      # This ext4 volume is used as a Steam library, and SteamLinuxRuntime (Pressure-Vessel)
      # needs to execute helper entry-points from within `steamapps/common/*Runtime*/`.
      # If this mount has `noexec`, Steam will fail with:
      #   ...SteamLinuxRuntime_sniper/_v2-entry-point: Permission denied
      #
      # We explicitly allow execution on this mount to support Steam runtimes.
      # (If you want a stricter setup, keep `noexec` and move the Steam library/runtimes
      # back to an internal `exec` filesystem.)
      "exec"

      # GNOME/Nautilus visibility fix:
      # Nautilus primarily shows "external drives" when they come from UDisks/GVFS.
      # This disk is mounted declaratively via NixOS (fstab/systemd), so it can be
      # mounted but not listed as a device in Nautilus.
      #
      # We don't want to change your stable mount or Steam path, so instead we:
      # 1) mark it as a user mount (helps some desktop integrations)
      # 2) add a persistent "Places" bookmark (below) so Nautilus shows it in the sidebar
      "user"
    ];
  };

  # Ensure the mountpoint is owned by your user so Steam/Proton can create prefixes that
  # are owned by you (Wine refuses to use prefixes not owned by the invoking user).
  systemd.tmpfiles.rules = [
    "d /mnt/arik_s_disk 0755 hydenix users - -"

    # GNOME/Nautilus sidebar entry:
    # Nautilus reads GTK bookmarks from `~/.config/gtk-3.0/bookmarks`.
    # Creating this file declaratively gives you a stable entry even when the disk
    # is mounted via systemd automount (as it is now).
    #
    # NOTE (mistake & correction):
    # I initially focused on "making Nautilus detect the device", but since this is
    # an fstab/systemd mount, the most reliable fix is a bookmark rather than trying
    # to force UDisks to own the mount.
    "d /home/hydenix/.config 0755 hydenix users - -"
    "d /home/hydenix/.config/gtk-3.0 0755 hydenix users - -"
    # NOTE (mistake & correction):
    # I previously used an apostrophe in the tmpfiles file-content field.
    # systemd-tmpfiles treats some characters as specifier/escape syntax in arguments,
    # which caused: "Failed to substitute specifiers in argument: Invalid slot".
    # Using a label without an apostrophe avoids tmpfiles parsing issues reliably.
    "f /home/hydenix/.config/gtk-3.0/bookmarks 0644 hydenix users - file:///mnt/arik_s_disk ariks%20disk\n"
  ];

  # User Account Setup - REQUIRED: Change "hydenix" to your desired username (must match above)
  users.users.hydenix = {
    isNormalUser = true;
    #Mistake: changing UID, doesnt have to change for steam to work with external ssd
    initialPassword = "hydenix"; # SECURITY: Change this password after first login with `passwd`
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ]; # User groups (determines permissions)
    # Default login shell.
    #
    # Why Nushell:
    # - You’re using Nushell (see project notes), so making it the login shell keeps interactive CLI behavior consistent.
    # - We already enable `programs.nushell` in Home Manager; setting it here ensures your TTY/login shell matches too.
    #
    # NOTE (mistake & correction):
    # I initially considered only configuring Nushell in Home Manager, but that would not change the actual
    # login shell for the user account. `users.users.<name>.shell` is the NixOS source-of-truth for that.
    shell = pkgs.nushell;
  };

  # Hydenix Configuration - Main configuration for the Hydenix desktop environment
  hydenix = {
    enable = true; # Enable Hydenix modules
    # Basic System Settings (REQUIRED):
    hostname = "hydenix"; # REQUIRED: Set your computer's network name (change to something unique)
    timezone = "America/Chicago"; # REQUIRED: Set timezone (examples: "America/New_York", "Europe/London", "Asia/Tokyo")
    locale = "en_CA.UTF-8"; # REQUIRED: Set locale/language (examples: "en_US.UTF-8", "en_GB.UTF-8", "de_DE.UTF-8")
    # For more configuration options, see: ./docs/options.md
  };

  services.gnome.gnome-keyring.enable = true;
  services.gvfs.enable = true;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"

      # Niri binary cache (sodiboo/niri-flake)
      # Why: avoids long local compiles by allowing Nix to download prebuilt niri derivations.
      "https://niri.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="

      # Niri binary cache public key (sodiboo/niri-flake)
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
  };

  # System Version - Don't change unless you know what you're doing (helps with system upgrades and compatibility)
  system.stateVersion = "25.05";
}
