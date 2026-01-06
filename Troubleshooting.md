Change ```backupFileExtension = "hm-bak3";``` and increment it to allow new pakages to overwrite configs
Sometimes have to run ```sudo mount -o remount,exec /mnt/arik_s_disk``` to make games work again because drive mounts with noexec
Do ```booted="$(readlink -f /run/booted-system)" 
ls -l /nix/var/nix/profiles/system-*-link | grep -F "$booted"``` to see what generation you're on
