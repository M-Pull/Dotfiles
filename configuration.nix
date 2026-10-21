{ user, ... }:

{
  # Determinate Nix owns the daemon and nix.conf. This switches off nix-darwin's
  # own Nix management; without it Determinate Nix does not work properly.
  determinateNix.enable = true;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = user;
  users.users.${user}.home = "/Users/${user}";

  # nix-darwin's own counter, set once at install time and never bumped.
  # Unrelated to home.stateVersion in home.nix.
  system.stateVersion = 6;
}
