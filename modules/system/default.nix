{ ... }:

{
  imports = [
    # ./example.nix - add your modules here
    ./plasma6.nix
    ./syncthing.nix
  ];

  environment.systemPackages = [
    # pkgs.vscode - hydenix's vscode version
    # pkgs.userPkgs.vscode - your personal nixpkgs version
  ];

  # Disable audio codec power saving to prevent buzzing noise when no audio is playing
  boot.kernelParams = [
    "snd_hda_intel.power_save=0"
    "snd_hda_intel.power_save_controller=N"
  ];
}
