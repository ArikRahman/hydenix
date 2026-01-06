<img align="right" width="75px" alt="NixOS" src="https://github.com/HyDE-Project/HyDE/blob/master/Source/assets/nixos.png?raw=true"/>

# troubleshooting & issues

## steam / proton

### SteamLinuxRuntime / Proton fails when Steam library is on a `noexec` mount

**Symptom**

Games may instantly exit and Steam logs show errors like:

- `.../SteamLinuxRuntime_sniper/_v2-entry-point: Permission denied`

**Cause**

Your Steam library is on a filesystem mounted with `noexec`. SteamLinuxRuntime (Pressure-Vessel) needs to execute helper entry-points inside `steamapps/common/*runtime*/` and will fail if execution is blocked.

**Fix**

- Preferred (reproducible): ensure the filesystem mount options do **not** include `noexec` (or explicitly include `exec`) for the mount that contains `SteamLibrary`.
- Quick one-off check: remount that filesystem with `exec`, then re-test launching the game.

Notes:
- If you intentionally want `noexec` for security, keep the data drive `noexec` and move your Steam library (or at least Steam runtimes/Proton) to an internal `exec` filesystem.

## nix errors

nix errors can be tricky to diagnose, but the below might assist in diagnosing the issue.

> [!TIP]
> rerun the command with `-v` to get more verbose output.
> you can also rerun the command with `--show-trace` to get a more detailed traceback.
> if the nix error is not clear, often the correct error message is somewhere in the *middle* of the error message.

## system errors & bugs

the following information is required when creating an issue, please provide as much as possible.
it's also possible to diagnose issues yourself with the information below.

1. **system logs**

   ```bash
   journalctl -b                                          # System logs
   sudo systemctl status home-manager-$HOSTNAME.service   # Home-manager status
   ```

2. **system information**

   ```bash
   nix-shell -p nix-info --run "nix-info -m"
   ```
