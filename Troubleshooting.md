 
Critical error: unable to nixos switch because Home manager times out because of mutability or something, will have to revisit:
but this command fixes it ```rm -rf ~/.config/hyde/themes \
       ~/.config/hyde/wallbash \
       ~/.local/share/hyde \
       ~/.local/share/wallbash \
       ~/.local/share/waybar/styles \
       ~/.vscode/extensions/prasanthrangan.wallbash```
- should be fixed now*     
Do ```booted="$(readlink -f /run/booted-system)" 
ls -l /nix/var/nix/profiles/system-*-link | grep -F "$booted"``` to see what nix generation you're on
- dota 2 audio cuts out whenf inding match, fix with launch option ```-sdlaudiodriver pulse```
Change ```backupFileExtension = "hm-bak3";``` and increment it to allow new pakages to overwrite configs
Sometimes have to run ```sudo mount -o remount,exec /mnt/arik_s_disk``` to make games work again because drive mounts with noexec
Do ```booted="$(readlink -f /run/booted-system)" 
ls -l /nix/var/nix/profiles/system-*-link | grep -F "$booted"``` to see what generation you're on
