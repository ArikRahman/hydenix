{ config, lib, pkgs, ... }:

{
  # KDE Plasma 6 desktop session
  #
  # Why: Hydenix is Hyprland-first, but enabling Plasma 6 here makes it available
  # as an additional session in your display manager (typically SDDM). This keeps
  # Hydenix intact while letting you choose Plasma at login.
  services.desktopManager.plasma6.enable = true;
}
