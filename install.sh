#!/usr/bin/env bash
# zsh + tmux one-shot installer (Apple Silicon macOS; tmux portion also works on Linux).
# Idempotent: safe to re-run. Backs up any existing real dotfiles before symlinking.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }

# Back up an existing real file (timestamped), drop an existing symlink,
# then symlink our version in. $1 = repo source path, $2 = target in $HOME.
link_dotfile() {
  local source="$1" target="$2"
  if [[ ! -e "$source" ]]; then
    warn "link_dotfile: source not found, aborting: $source"
    return 1
  fi
  if [[ -e "$target" && ! -L "$target" ]]; then
    local backup="$target.backup-$TS"
    log "Backing up existing $target to $backup"
    mv "$target" "$backup"
  elif [[ -L "$target" ]]; then
    log "Removing existing symlink $target"
    rm "$target"
  fi
  ln -s "$source" "$target"
  ok "Linked $target -> $source"
}

# ── 1. Bootstrap Homebrew (macOS only) ────────────────────────────────────────
if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    log "Homebrew not found — installing (this prompts for sudo and may take a while)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Make brew usable for the rest of this run (Apple Silicon path — see spec scope).
    if [[ ! -x /opt/homebrew/bin/brew ]]; then
      warn "Homebrew install finished but /opt/homebrew/bin/brew is missing — cannot continue"
      exit 1
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "Homebrew installed"
  else
    ok "Homebrew already present"
  fi
fi

# ── 2. Ensure tmux is installed ───────────────────────────────────────────────
if ! command -v tmux >/dev/null 2>&1; then
  if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
    log "tmux not found — installing via Homebrew"
    brew install tmux
  else
    warn "tmux not found. Install with your package manager and re-run, e.g.:"
    echo "    sudo apt install tmux      # Debian/Ubuntu"
    echo "    sudo dnf install tmux      # Fedora"
    echo "    brew install tmux          # macOS"
    exit 1
  fi
fi
ok "tmux $(tmux -V | awk '{print $2}')"

# ── 3. Symlink tmux.conf ──────────────────────────────────────────────────────
link_dotfile "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

# ── 4. Install TPM (tmux plugin manager) ──────────────────────────────────────
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
  log "Installing TPM"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
  ok "TPM already present"
fi

# ── 5. Install plugins listed in tmux.conf ────────────────────────────────────
log "Installing tmux plugins via TPM"
"$TPM_DIR/bin/install_plugins" >/dev/null
ok "Plugins installed"

# ── 6. zsh environment (macOS only) ───────────────────────────────────────────
if [[ "$(uname -s)" == "Darwin" ]]; then
  # 6a. Oh My Zsh — unattended so it neither rewrites ~/.zshrc nor launches a shell.
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh My Zsh installed"
  else
    ok "Oh My Zsh already present"
  fi

  # 6b. Powerlevel10k theme.
  P10K_DIR="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [[ ! -d "$P10K_DIR" ]]; then
    log "Installing Powerlevel10k"
    git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    ok "Powerlevel10k installed"
  else
    ok "Powerlevel10k already present"
  fi

  # 6c. zsh-syntax-highlighting (Homebrew).
  if ! brew list zsh-syntax-highlighting >/dev/null 2>&1; then
    log "Installing zsh-syntax-highlighting"
    brew install zsh-syntax-highlighting
    ok "zsh-syntax-highlighting installed"
  else
    ok "zsh-syntax-highlighting already present"
  fi

  # 6d. Symlink the zsh dotfiles (existing real files are backed up timestamped).
  link_dotfile "$DOTFILES_DIR/zsh/zshrc"    "$HOME/.zshrc"
  link_dotfile "$DOTFILES_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"
  link_dotfile "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"
fi

# ── 7. (Optional) install JetBrainsMono Nerd Font for the catppuccin glyphs ──
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
  # On macOS with Homebrew, the cask is the cleaner path (brew-managed,
  # upgradable). Fall back to a direct zip download otherwise.
  if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
    read -r -p "Install JetBrainsMono Nerd Font via Homebrew cask? [y/N] " ans
    ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
    if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
      log "Running: brew install --cask font-jetbrains-mono-nerd-font"
      brew install --cask font-jetbrains-mono-nerd-font
      ok "JetBrainsMono Nerd Font installed via Homebrew"
    else
      warn "Skipped font install. catppuccin glyphs will look broken until a Nerd Font is set in your terminal."
    fi
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
fi

# ── 8. Reload running tmux server, if any ─────────────────────────────────────
if tmux info >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf"
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

if [[ "$(uname -s)" == "Darwin" ]]; then
  cat <<'EOF'
zsh: Oh My Zsh + Powerlevel10k are configured. Open a new terminal,
     or run `exec zsh`, to load the new shell environment.

EOF
fi
