# dotfiles

My personal config for tmux and friends. One-line setup on any new Linux/macOS box.

Tested on Ubuntu and macOS. Installer uses bash 3.2-compatible syntax (works with Apple's default `/bin/bash`).

## Quick install

```bash
git clone https://github.com/<your-user>/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

The installer:

1. Verifies `tmux` is on `PATH`.
2. Backs up an existing `~/.tmux.conf` (timestamped) and symlinks the version in this repo.
3. Clones [TPM](https://github.com/tmux-plugins/tpm) if missing.
4. Installs all plugins declared in `tmux/tmux.conf` (catppuccin theme, yank, vim-tmux-navigator, sensible).
5. *Optionally* downloads JetBrainsMono Nerd Font. Destination depends on OS: `~/.local/share/fonts/` (Linux), `~/Library/Fonts/` (macOS). Skip with `n` if you don't want it.
6. Reloads any running tmux server.

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
└── tmux/
    └── tmux.conf
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
