# Dotfiles

macOS configuration managed with nix-darwin and Home Manager on Determinate Nix.
One repo, one command, and a fresh Mac ends up configured the same way every time.

## Fresh machine

On a brand new Apple Silicon Mac, open Terminal and run:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/M-Pull/Dotfiles/main/bootstrap.sh)"
```

It asks for your password once and nothing else. In order it installs the
Xcode Command Line Tools and Determinate Nix, clones this repo to `~/Dotfiles`
(linked from `~/.dotfiles`), and runs the first `darwin-rebuild switch`
through `rebuild.sh`. Safe to re-run: every step skips itself when done.

Using a fork? Append `- <your-repo-url>` to the command, and set `user` in
`flake.nix` to your macOS account name.

## Daily use

```sh
~/Dotfiles/rebuild.sh   # apply the current config
```

`flake.lock` is generated and validated by CI and committed to main; the
bootstrap refuses to run without it, and `rebuild.sh` never updates it.
