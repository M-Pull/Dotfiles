{ user, ... }:

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";

  # Home Manager's own counter: the release current at first install, never bumped.
  # Unrelated to system.stateVersion in configuration.nix.
  home.stateVersion = "26.05";
}
