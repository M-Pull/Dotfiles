{
  description = "Dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # No `follows` on purpose: Determinate's README advises against it (FlakeHub cache misses).
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  outputs =
    { nix-darwin, home-manager, nix-homebrew, determinate, ... }:
    let
      # Must equal the macOS account name. bootstrap.sh checks it before the first switch.
      user = "iceBear";
      host = "mac";
    in
    {
      darwinConfigurations.${host} = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user; };
        modules = [
          determinate.darwinModules.default
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          ./configuration.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };
    };
}
