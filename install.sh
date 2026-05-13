#!/usr/bin/env bash
# tmux + Nerd Font one-shot installer.
# Idempotent: safe to re-run. Backs up any existing ~/.tmux.conf.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }

# ── 1. Ensure tmux is installed ───────────────────────────────────────────────
if ! command -v tmux >/dev/null 2>&1; then
  warn "tmux not found. Install with your package manager and re-run, e.g.:"
  echo "    sudo apt install tmux      # Debian/Ubuntu"
  echo "    sudo dnf install tmux      # Fedora"
  echo "    brew install tmux          # macOS"
  exit 1
fi
ok "tmux $(tmux -V | awk '{print $2}')"

# ── 2. Symlink tmux.conf ──────────────────────────────────────────────────────
TARGET="$HOME/.tmux.conf"
SOURCE="$DOTFILES_DIR/tmux/tmux.conf"

if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
  BACKUP="$TARGET.backup-$TS"
  log "Backing up existing ~/.tmux.conf to $BACKUP"
  mv "$TARGET" "$BACKUP"
elif [[ -L "$TARGET" ]]; then
  log "Removing existing symlink"
  rm "$TARGET"
fi

ln -s "$SOURCE" "$TARGET"
ok "Linked $TARGET -> $SOURCE"

# ── 3. Install TPM (tmux plugin manager) ──────────────────────────────────────
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
  log "Installing TPM"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
  ok "TPM already present"
fi

# ── 4. Install plugins listed in tmux.conf ────────────────────────────────────
log "Installing tmux plugins via TPM"
"$TPM_DIR/bin/install_plugins" >/dev/null
ok "Plugins installed"

# ── 5. (Optional) install JetBrainsMono Nerd Font for the catppuccin glyphs ──
# Skips if a Nerd Font is already detected. SSH users: the font has to be
# installed on your *client* machine (the one rendering the terminal),
# not the server you SSH into.
if command -v fc-list >/dev/null 2>&1; then
  if fc-list | grep -qi "nerd"; then
    ok "A Nerd Font is already installed"
  else
    read -r -p "Install JetBrainsMono Nerd Font to ~/.local/share/fonts? [y/N] " ans
    if [[ "${ans,,}" == "y" ]]; then
      log "Downloading JetBrainsMono Nerd Font (~120 MB)"
      tmp="$(mktemp -d)"
      curl -fsSL -o "$tmp/JetBrainsMono.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
      mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd"
      unzip -q -o "$tmp/JetBrainsMono.zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerd/"
      rm -rf "$tmp"
      fc-cache -f "$HOME/.local/share/fonts/" >/dev/null
      ok "JetBrainsMono Nerd Font installed"
    else
      warn "Skipped font install. catppuccin glyphs will look broken until a Nerd Font is set in your terminal."
    fi
  fi
else
  warn "fc-list not available; skipping font check (likely macOS or minimal container)."
fi

# ── 6. Reload running tmux server, if any ─────────────────────────────────────
if tmux info >/dev/null 2>&1; then
  tmux source-file "$TARGET"
  ok "Reloaded running tmux server"
fi

cat <<'EOF'

╭───────────────────────────────────────────────────────────╮
│  Done. Quick start:                                       │
│    tmux new -s work -n editor                             │
│  Prefix is backtick (`). Common keys:                     │
│    ` |   split vertical          ` -   split horizontal   │
│    ` h/j/k/l   move between panes                         │
│    ` s   pick session            ` ,   rename window      │
│    ` r   reload config           ` d   detach             │
│                                                           │
│  If glyphs in the status bar look broken, your terminal   │
│  font isn't a Nerd Font. Set it in your terminal app      │
│  (Windows Terminal / iTerm2 / gnome-terminal / etc).      │
╰───────────────────────────────────────────────────────────╯
EOF
