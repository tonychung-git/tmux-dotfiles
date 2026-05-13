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
# SSH users: install the font on the *client* (the box rendering the terminal),
# not the server you SSH into.
OS="$(uname -s)"
case "$OS" in
  Linux)  FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd" ;;
  Darwin) FONT_DIR="$HOME/Library/Fonts/JetBrainsMonoNerd" ;;
  *)      FONT_DIR="" ;;
esac

font_already_installed() {
  case "$OS" in
    Linux)  command -v fc-list >/dev/null 2>&1 && fc-list | grep -qi "nerd" ;;
    Darwin) ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi "nerd" ;;
    *)      return 1 ;;
  esac
}

if [[ -z "$FONT_DIR" ]]; then
  warn "Unrecognised OS ($OS); skipping font install."
elif font_already_installed; then
  ok "A Nerd Font is already installed"
else
  read -r -p "Install JetBrainsMono Nerd Font to $FONT_DIR? [y/N] " ans
  ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
    log "Downloading JetBrainsMono Nerd Font (~120 MB)"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/JetBrainsMono.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    mkdir -p "$FONT_DIR"
    unzip -q -o "$tmp/JetBrainsMono.zip" -d "$FONT_DIR/"
    rm -rf "$tmp"
    if [[ "$OS" == "Linux" ]] && command -v fc-cache >/dev/null 2>&1; then
      fc-cache -f "$(dirname "$FONT_DIR")" >/dev/null
    fi
    ok "JetBrainsMono Nerd Font installed to $FONT_DIR"
  else
    warn "Skipped font install. catppuccin glyphs will look broken until a Nerd Font is set in your terminal."
  fi
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
