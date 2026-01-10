{
  config,
  lib,
  pkgs,
  ...
}:

# NVIDIA + Wayland (Hyprland) suspend/resume fix module
#
# Symptom:
# - System resumes (TTY works), but graphical session returns to a black screen.
# - On NVIDIA (proprietary driver) this is commonly the driver failing to restore
#   modesetting / VRAM on resume, especially on Wayland compositors.
#
# Why this module exists:
# - Keep all resume-related mitigations in one place, so you can disable/revert
#   them quickly if they don't help.
# - Prefer minimal, well-known NixOS knobs over ad-hoc scripts.
#
# NOTE:
# - This module assumes you're using the proprietary NVIDIA driver (`nvidia`).
# - If you're on `nouveau`, these options won't help and you should switch stacks
#   or follow nouveau-specific guidance.
#
# Mistake & correction (Manus requirement):
# - A common mistake is to treat this as a full system hang and tweak random PM
#   settings. Your evidence (TTY works on black screen) indicates the OS is alive;
#   the graphics stack is what's failing, so we focus on NVIDIA KMS + resume helpers.

let
  cfg = config.hydenix.system.nvidiaSleepFix;
in
{
  options.hydenix.system.nvidiaSleepFix = {
    enable = lib.mkEnableOption "NVIDIA suspend/resume reliability tweaks for Wayland (Hyprland)";

    # Enable a conservative workaround: restart the display manager after resume.
    #
    # Why:
    # - If the kernel resumes but the Wayland session doesn't repaint, bouncing the
    #   DM is a pragmatic recovery.
    #
    # Trade-off:
    # - This will terminate the current graphical session on resume if it triggers.
    # - Prefer fixing the driver path first; enable this only if logs indicate the
    #   session/DM is stuck and this recovers reliably.
    restartDisplayManagerOnResume = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to restart `display-manager.service` after resume as a workaround.
        Enable only if your system resumes (TTY works), but the graphical login/session
        is consistently black and restarting the display manager from TTY fixes it.
      '';
    };

    # Some systems behave better with `deep` (S3) than s2idle.
    #
    # We keep this off by default because it is hardware/firmware dependent.
    forceDeepSleep = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If enabled, sets `mem_sleep_default=deep` to prefer S3 (deep) suspend.
        Use this if long `s2idle` sleeps correlate with resume black screens.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    # --- Core NVIDIA resume mitigations (proprietary driver) -------------------
    #
    # 1) Enable kernel modesetting for NVIDIA DRM.
    #    Why: Required for Wayland compositors and often improves resume behavior.
    #
    # 2) Enable NVIDIA's power management integration.
    #    Why: Enables systemd sleep helpers (`nvidia-suspend`, `nvidia-resume`,
    #         `nvidia-hibernate`) and VRAM preservation where supported.
    #
    # These are the highest-value, lowest-risk fixes for your symptom bucket.
    hardware.nvidia = {
      # Keep this in one place. If you already set `hardware.nvidia` elsewhere,
      # merge there and comment out duplicates rather than deleting.
      modesetting.enable = lib.mkDefault true;

      powerManagement = {
        enable = lib.mkDefault true;

        # Fine-grained power management is generally beneficial on modern GPUs,
        # but if you see instability, set this to false.
        finegrained = lib.mkDefault true;
      };
    };

    # Ensure we are using the proprietary driver stack.
    # If your config already sets `services.xserver.videoDrivers`, do not duplicate.
    services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ];

    # Many Wayland+NVIDIA setups rely on DRM KMS being enabled early.
    # NixOS typically wires this when `hardware.nvidia.modesetting.enable = true`,
    # but we include the explicit kernel param as a belt-and-suspenders default.
    #
    # NOTE: If you already have `boot.kernelParams` elsewhere, Nix will merge lists.
    boot.kernelParams = [
      "nvidia-drm.modeset=1"
    ]
    ++ lib.optionals cfg.forceDeepSleep [
      # Why: Some firmware/GPU combinations resume more reliably from S3 (deep)
      # than from s2idle (modern standby).
      "mem_sleep_default=deep"
    ];

    # Improve the odds that NVIDIA's resume helpers are available.
    # On NixOS, these are typically managed automatically when powerManagement is enabled,
    # but we ensure `systemd` is allowed to use them.
    #
    # NOTE: If you see evaluation warnings about unknown units, that means your
    # driver build isn't exposing these targets; check logs and adjust.
    systemd.services."nvidia-resume".wantedBy = lib.mkDefault [ "sleep.target" ];

    # --- Optional workaround: restart display-manager after resume -------------
    #
    # Only enable if:
    # - TTY works during the black screen
    # - `systemctl restart display-manager` restores graphics reliably
    #
    # This is a workaround, not the ideal fix.
    systemd.services.hydenix-restart-display-manager-after-resume =
      lib.mkIf cfg.restartDisplayManagerOnResume
        {
          description = "Hydenix workaround: restart display manager after resume (Wayland/NVIDIA black screen)";
          after = [
            "suspend.target"
            "hibernate.target"
            "hybrid-sleep.target"
          ];
          wantedBy = [
            "suspend.target"
            "hibernate.target"
            "hybrid-sleep.target"
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/systemctl restart display-manager.service";
          };
        };

    # --- Logging hints (non-invasive) -----------------------------------------
    #
    # Why:
    # - When debugging resume, logs are everything. We don't force extra logging
    #   globally here, but we add comments so you know where to look.
    #
    # Tip:
    # - After a failed resume that required power cycling:
    #   `journalctl -b -1 | grep -iE 'PM: resume|drm|nvidia|NVRM|Xid|hypr|wayland'`
  };
}
