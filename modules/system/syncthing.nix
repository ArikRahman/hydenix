{ config, lib, ... }:

let
  # Prefer the first Home Manager user, since this repo already wires HM users
  # in `configuration.nix`. Fall back to a common default.
  hmUsers =
    lib.attrNames (
      if (config ? home-manager) && (config.home-manager ? users) then
        config.home-manager.users
      else
        { }
    );
  primaryUser =
    if hmUsers != [ ] then
      builtins.head hmUsers
    else if (config.users.users ? hydenix) then
      "hydenix"
    else
      "user";
in
{
  services.syncthing = {
    enable = true;

    # Run Syncthing as the primary (Home Manager) user so it can access the
    # user’s home directories and files.
    user = primaryUser;
    group = "users";

    # Keep Syncthing’s config/state in the user’s home.
    dataDir = "/home/${primaryUser}";
    configDir = "/home/${primaryUser}/.config/syncthing";

    # Security default: local-only GUI. If you change this to 0.0.0.0:8384,
    # also open the firewall for 8384/TCP or use a reverse proxy.
    guiAddress = "127.0.0.1:8384";

    # Opens Syncthing's default ports (sync + local discovery):
    # - 22000/TCP+UDP
    # - 21027/UDP
    openDefaultPorts = true;
  };
}
