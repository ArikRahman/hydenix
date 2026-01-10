{ ... }:

{
  imports = [
    # ./example.nix - add your modules here
    ./plasma6.nix
    ./syncthing.nix

    # NVIDIA suspend/resume black-screen fix module (Wayland/Hyprland reliability)
    # Why: On NVIDIA + Wayland, resume can return to a black screen while TTY still works.
    # This module will enable NVIDIA modesetting + systemd sleep integration so the GPU
    # re-initializes cleanly after suspend.
    ./nvidia-sleep-fix.nix
  ];

  environment.systemPackages = [
    # pkgs.vscode - hydenix's vscode version
    # pkgs.userPkgs.vscode - your personal nixpkgs version
  ];

  # Hibernate: configure the resume device.
  #
  # Why:
  # - You have a swap partition configured (see `hardware-configuration.nix`), but your kernel cmdline
  #   does not include a resume device and the kernel logs show `PM: Image not found (code -16)`,
  #   which commonly causes hibernate to "return immediately" instead of powering off.
  #
  # What:
  # - Point resume at the swap partition UUID already used by `swapDevices`.
  # - This allows the initrd/kernel to find a hibernation image and resume correctly.
  boot.resumeDevice = "/dev/disk/by-uuid/82250e78-4142-4376-bef7-200b513b7417";

  # Disable audio codec power saving to prevent buzzing noise when no audio is playing
  boot.kernelParams = [
    "snd_hda_intel.power_save=0"
    "snd_hda_intel.power_save_controller=N"
  ];
}
