{
  description = "template for hydenix";

  inputs = {
    # Your nixpkgs
    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Hydenix
    hydenix = {
      # Available inputs:
      # Main: github:richen604/hydenix
      # Commit: github:richen604/hydenix/<commit-hash>
      # Version: github:richen604/hydenix/v1.0.0 - note the version may not be compatible with this template
      url = "github:richen604/hydenix";

      # uncomment the below if you know what you're doing, hydenix updates nixos-unstable every week or so
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware Configuration's, used in ./configuration.nix. Feel free to remove if unused
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
  };

  outputs =
    inputs:
    let
      system = "x86_64-linux";

      /*
        we define pkgs using hydenix's nixpkgs, this allows some options for extending hydenix

        1. uncomment `inputs.nixpkgs.follows = "nixpkgs";` in the hydenix input above to always use the latest nixpkgs
        2. control your own nixpkgs by changing `inputs.hydenix.inputs.nixpkgs` below to `inputs.nixpkgs`
        3. add overlays below to extend and version pin incrementally
      */
      pkgs = import inputs.hydenix.inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          inputs.hydenix.overlays.default
        ];
      };

      # again if you want to control your own nixpkgs, remove `inputs.hydenix` below and keep `inputs.nixpkgs`
      hydenixConfig = inputs.hydenix.inputs.nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = {
          inherit inputs;
        };
        modules = [
          # Record the flake's Git revision into the built system closure so each
          # NixOS generation can be mapped back to the exact commit.
          #
          # Query it with:
          #   nixos-version --configuration-revision
          #
          # NOTE: If the flake source is "dirty", Nix may provide `self.dirtyRev`.
          # If neither revision is available, this becomes `null`.
          (
            { ... }:
            {
              system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
            }
          )
          inputs.niri.nixosModules.niri
          ./configuration.nix
        ];
      };

      vmConfig = inputs.hydenix.lib.vmConfig {
        inherit inputs pkgs;
        nixosConfiguration = hydenixConfig;
      };

    in
    {
      nixosConfigurations.hydenix = hydenixConfig;
      nixosConfigurations.default = hydenixConfig;
      packages.${system}.vm = vmConfig.config.system.build.vm;
    };
}
