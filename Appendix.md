## This is where commands are saved for future reference
do  ```git config --local credential.helper '!gh auth git-credential'``` to enable github cli authentication for git
do  ```sudo nixos-rebuild switch --flake .#hydenix ``` to update nixos
do  ```sudo chown -R hydenix:users /mnt/arik_s_disk/SteamLibrary/steamapps/compatdata``` to fix steam proton prefix ownership issues
do  ```nix flake update``` to update flake inputs
do  ```gh auth login``` to login to github cli
do  ```gh repo clone ArikRahman/hydenix``` to clone hydenix repo
do Optional: run ```nix flake update nixpkgs``` which will make Unstraightened reuse more dependencies already on your system.
- dota 2 audio cuts out whenf inding match, fix with launch option ```-sdlaudiodriver pulse```
