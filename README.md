# dotfiles

My personal config for zsh and tmux. One-line setup on a new macOS box (the tmux portion also works on Linux).

Tested on Ubuntu and macOS. Installer uses bash 3.2-compatible syntax (works with Apple's default `/bin/bash`).

## Quick install

```bash
git clone https://github.com/tonychung-git/tmux-dotfiles.git ~/dotfiles && ~/dotfiles/install.sh
```
or
```bash
git clone git@github.com:tonychung-git/tmux-dotfiles.git ~/dotfiles && ~/dotfiles/install.sh
```

> The clone URL is SSH, so a fresh Mac needs an SSH key registered with GitHub first
> (<https://docs.github.com/en/authentication/connecting-to-github-with-ssh>). No key yet?
> Use the HTTPS URL instead:
> `git clone https://github.com/tonychung-git/tmux-dotfiles.git ~/dotfiles && ~/dotfiles/install.sh`

The installer:

1. **macOS:** installs [Homebrew](https://brew.sh) if it's missing.
2. Ensures `tmux` is installed (macOS: via Homebrew; Linux: auto-detects your package manager — apt/dnf/pacman/zypper/apk — and installs it, which may prompt for your sudo password).
3. Backs up an existing `~/.tmux.conf` (timestamped) and symlinks the version in this repo.
4. Clones [TPM](https://github.com/tmux-plugins/tpm) if missing.
5. Installs all plugins declared in `tmux/tmux.conf` (catppuccin theme, yank, vim-tmux-navigator, sensible).
6. **macOS:** sets up the zsh environment — [Oh My Zsh](https://ohmyz.sh), the [Powerlevel10k](https://github.com/romkatv/powerlevel10k) theme, and `zsh-syntax-highlighting` — then symlinks `~/.zshrc`, `~/.p10k.zsh`, and `~/.zprofile` from this repo (existing files are backed up timestamped).
7. *Optionally* installs JetBrainsMono Nerd Font — on macOS via a Homebrew cask (brew-managed), on Linux downloaded to `~/.local/share/fonts/`. Skip with `n` if you don't want it.
8. Reloads any running tmux server.

The zsh setup targets macOS on Apple Silicon; on Linux the installer does the tmux steps and skips zsh.

Re-running is safe — it's idempotent.

## SSH'ing from a Windows / macOS workstation?

Fonts live on whatever machine is **drawing** the terminal, not the box you SSH into. If you SSH from Windows Terminal / iTerm2 / etc., install the Nerd Font on the **client** machine and set it as the terminal's font there. Installing the font on the SSH server has zero effect on what you see.

For Windows + Windows Terminal:

1. Download `JetBrainsMono.zip` from <https://github.com/ryanoasis/nerd-fonts/releases/latest>.
2. Right-click the extracted `.ttf` files → *Install for all users*.
3. `Ctrl + ,` in Windows Terminal → *Profiles → Defaults → Appearance → Font face* → `JetBrainsMono Nerd Font Mono`.
4. Close and reopen Windows Terminal.

## Keymap cheatsheet

Prefix is **`` ` ``** (backtick).

| Action                                | Keys              |
| ------------------------------------- | ----------------- |
| Reload config                         | `` ` `` `r`       |
| Vertical split (keeps cwd)            | `` ` `` `|`       |
| Horizontal split (keeps cwd)          | `` ` `` `-`       |
| New window (keeps cwd)                | `` ` `` `c`       |
| Move between panes (vim-style)        | `` ` `` `h/j/k/l` |
| Pick session interactively            | `` ` `` `s`       |
| Rename window                         | `` ` `` `,`       |
| Detach session                        | `` ` `` `d`       |
| Copy mode (vi keys, `v` select / `y`) | `` ` `` `[`       |

`tmux new -s <session> -n <window>` creates a session with a named first window.

## Layout

```
dotfiles/
├── README.md
├── install.sh
├── tmux/
│   └── tmux.conf
└── zsh/
    ├── zshrc       # generic .zshrc (Oh My Zsh + Powerlevel10k + syntax highlighting)
    ├── p10k.zsh    # Powerlevel10k appearance config
    └── zprofile    # loads Homebrew into PATH
```

## Adding more configs later

The structure is intentionally flat. To add (say) `nvim`:

```
dotfiles/
├── nvim/
│   └── init.lua
└── tmux/tmux.conf
```

Then extend `install.sh` with another symlink step.
