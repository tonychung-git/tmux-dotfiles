# zsh + tmux Fresh-macOS Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `~/dotfiles` so that `git clone … && ~/dotfiles/install.sh` sets up the zsh environment (Oh My Zsh + Powerlevel10k + zsh-syntax-highlighting) alongside the existing tmux setup on a fresh macOS.

**Architecture:** Single flat repo, single `install.sh`. A new `zsh/` folder holds the versioned shell config. `install.sh` gains a Homebrew bootstrap, automatic tmux install on macOS, and a macOS-only zsh block; symlinking is unified behind one `link_dotfile` helper. The zsh block is guarded by `uname` so Linux behaviour is unchanged.

**Tech Stack:** Bash (installer, `#!/usr/bin/env bash`, `set -euo pipefail`), zsh (the config being managed), Homebrew, git.

**Testing note:** This repo has no test framework and shell installers are not unit-testable in isolation (they install Homebrew, Oh My Zsh, etc.). Following the existing repo's pattern, per-task verification is `bash -n` (syntax — hard gate) plus `shellcheck` (advisory if installed). Task 8 is the integration test: an idempotent re-run of `install.sh` on this machine plus symlink inspection, exactly as the spec's Testing section prescribes.

**Branch:** Work happens on the existing `zsh-dotfiles` branch (already checked out, design spec already committed there).

---

## File Structure

| File | Create/Modify | Responsibility |
|------|---------------|----------------|
| `zsh/zshrc` | Create | Generic `.zshrc` — Oh My Zsh template + Powerlevel10k theme + zsh-syntax-highlighting source. No secrets, no machine-specific PATH. |
| `zsh/p10k.zsh` | Create | Verbatim copy of the owner's `~/.p10k.zsh` — the configured Powerlevel10k appearance. |
| `zsh/zprofile` | Create | Verbatim copy of `~/.zprofile` — loads Homebrew into PATH for login shells. |
| `install.sh` | Modify | Add `link_dotfile` helper, Homebrew bootstrap, macOS tmux install, the zsh block, and a zsh line in the summary. |
| `README.md` | Modify | Mention zsh, add `zsh/` to Layout, document the SSH-key precondition. |

---

## Task 1: Add the versioned zsh config files

**Files:**
- Create: `zsh/zprofile`
- Create: `zsh/p10k.zsh`
- Create: `zsh/zshrc`

Note: this task reads from the *current* `~/.zshrc` / `~/.p10k.zsh` / `~/.zprofile`, which still hold their original content (nothing in this plan modifies them until Task 8 runs the installer).

- [ ] **Step 1: Copy the two files that go in verbatim**

```bash
cd ~/dotfiles
mkdir -p zsh
cp ~/.zprofile  zsh/zprofile
cp ~/.p10k.zsh  zsh/p10k.zsh
```

- [ ] **Step 2: Create `zsh/zshrc` from `~/.zshrc`, dropping the trailing non-setup lines**

The current `~/.zshrc` ends with three things that are NOT part of the zsh/tmux setup and must not enter the repo: `export PATH="$HOME/.local/bin:$PATH"`, the `CLOUDFLARE_API_TOKEN` export, and the `node@22` PATH export. They are the last block of the file — everything from `export PATH="$HOME/.local/bin:$PATH"` onward. The last line to KEEP is the `zsh-syntax-highlighting.zsh` source line. This `sed` keeps lines 1 through that line (inclusive) and drops the rest:

```bash
cd ~/dotfiles
sed -n '1,/zsh-syntax-highlighting\.zsh/p' ~/.zshrc > zsh/zshrc
```

- [ ] **Step 3: Verify the strip — excluded content gone, kept content present**

```bash
cd ~/dotfiles
echo "--- these must produce NO output: ---"
grep -nE 'CLOUDFLARE_API_TOKEN|node@22|\.local/bin' zsh/zshrc
echo "--- these must produce matches: ---"
grep -nE 'oh-my-zsh|powerlevel10k|zsh-syntax-highlighting' zsh/zshrc
```

Expected: the first `grep` prints nothing (exit status 1). The second `grep` prints at least 3 matching lines (the `ZSH=` / `ZSH_THEME=` / `source` lines).

- [ ] **Step 4: Syntax-check all three files**

```bash
cd ~/dotfiles
zsh -n zsh/zshrc && zsh -n zsh/zprofile && zsh -n zsh/p10k.zsh && echo "SYNTAX OK"
```

Expected: prints `SYNTAX OK`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add zsh/zshrc zsh/p10k.zsh zsh/zprofile
git commit -m "Add versioned zsh config (zshrc, p10k.zsh, zprofile)"
```

---

## Task 2: Add the `link_dotfile` helper and route the tmux.conf step through it

**Files:**
- Modify: `install.sh` (helper functions block; section 2; section 6 reload)

Currently `install.sh` open-codes the "back up existing file, symlink ours" logic for `tmux.conf` only. This task extracts it into one `link_dotfile` helper so Task 5 can reuse it for the three zsh files (DRY).

- [ ] **Step 1: Add the `link_dotfile` helper after the existing `ok()` helper**

Find this block in `install.sh`:

```bash
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }
```

Replace it with:

```bash
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }

# Back up an existing real file (timestamped), drop an existing symlink,
# then symlink our version in. $1 = repo source path, $2 = target in $HOME.
link_dotfile() {
  local source="$1" target="$2"
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
```

- [ ] **Step 2: Replace the body of the tmux.conf section with a `link_dotfile` call**

Find this block in `install.sh`:

```bash
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
```

Replace it with:

```bash
# ── 2. Symlink tmux.conf ──────────────────────────────────────────────────────
link_dotfile "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
```

- [ ] **Step 3: Fix the reload section, which referenced the now-removed `$TARGET`**

Find this block in `install.sh`:

```bash
# ── 6. Reload running tmux server, if any ─────────────────────────────────────
if tmux info >/dev/null 2>&1; then
  tmux source-file "$TARGET"
  ok "Reloaded running tmux server"
fi
```

Replace it with:

```bash
# ── 6. Reload running tmux server, if any ─────────────────────────────────────
if tmux info >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf"
  ok "Reloaded running tmux server"
fi
```

- [ ] **Step 4: Syntax-check**

```bash
cd ~/dotfiles
bash -n install.sh && echo "SYNTAX OK"
command -v shellcheck >/dev/null && shellcheck install.sh || echo "(shellcheck not installed — skipped)"
```

Expected: prints `SYNTAX OK`, exit 0. If `shellcheck` runs, the new `link_dotfile` code should introduce no new errors.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add install.sh
git commit -m "Extract link_dotfile helper, route tmux.conf through it"
```

---

## Task 3: Add the Homebrew bootstrap step and renumber sections

**Files:**
- Modify: `install.sh` (new section 1; renumber existing section header comments)

On a fresh Mac there is no Homebrew, and tmux + zsh-syntax-highlighting + the Nerd Font cask all need it. This adds a macOS-only bootstrap as the new section 1.

- [ ] **Step 1: Insert the Homebrew bootstrap section**

Find this block in `install.sh`:

```bash
# ── 1. Ensure tmux is installed ───────────────────────────────────────────────
if ! command -v tmux >/dev/null 2>&1; then
```

Replace it with:

```bash
# ── 1. Bootstrap Homebrew (macOS only) ────────────────────────────────────────
if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    log "Homebrew not found — installing (this prompts for sudo and may take a while)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Make brew usable for the rest of this run (Apple Silicon path — see spec scope).
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "Homebrew installed"
  else
    ok "Homebrew already present"
  fi
fi

# ── 2. Ensure tmux is installed ───────────────────────────────────────────────
if ! command -v tmux >/dev/null 2>&1; then
```

- [ ] **Step 2: Renumber the remaining section header comments**

Apply these one-line replacements in `install.sh` (only the section number changes; the dashes and text stay). Section 6 is intentionally left free for the zsh block added in Task 5.

Find: `# ── 2. Symlink tmux.conf ──────────────────────────────────────────────────────`
Replace: `# ── 3. Symlink tmux.conf ──────────────────────────────────────────────────────`

Find: `# ── 3. Install TPM (tmux plugin manager) ──────────────────────────────────────`
Replace: `# ── 4. Install TPM (tmux plugin manager) ──────────────────────────────────────`

Find: `# ── 4. Install plugins listed in tmux.conf ────────────────────────────────────`
Replace: `# ── 5. Install plugins listed in tmux.conf ────────────────────────────────────`

Find: `# ── 5. (Optional) install JetBrainsMono Nerd Font for the catppuccin glyphs ──`
Replace: `# ── 7. (Optional) install JetBrainsMono Nerd Font for the catppuccin glyphs ──`

Find: `# ── 6. Reload running tmux server, if any ─────────────────────────────────────`
Replace: `# ── 8. Reload running tmux server, if any ─────────────────────────────────────`

- [ ] **Step 3: Syntax-check**

```bash
cd ~/dotfiles
bash -n install.sh && echo "SYNTAX OK"
command -v shellcheck >/dev/null && shellcheck install.sh || echo "(shellcheck not installed — skipped)"
```

Expected: prints `SYNTAX OK`, exit 0.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add install.sh
git commit -m "Bootstrap Homebrew on macOS when missing"
```

---

## Task 4: Auto-install tmux via Homebrew on macOS

**Files:**
- Modify: `install.sh` (section 2 — the tmux check)

Today the script exits with instructions if tmux is missing. On macOS, Homebrew is now guaranteed present (Task 3), so it can just install tmux. Linux behaviour is unchanged.

- [ ] **Step 1: Replace the tmux check**

Find this block in `install.sh`:

```bash
# ── 2. Ensure tmux is installed ───────────────────────────────────────────────
if ! command -v tmux >/dev/null 2>&1; then
  warn "tmux not found. Install with your package manager and re-run, e.g.:"
  echo "    sudo apt install tmux      # Debian/Ubuntu"
  echo "    sudo dnf install tmux      # Fedora"
  echo "    brew install tmux          # macOS"
  exit 1
fi
ok "tmux $(tmux -V | awk '{print $2}')"
```

Replace it with:

```bash
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
```

- [ ] **Step 2: Syntax-check**

```bash
cd ~/dotfiles
bash -n install.sh && echo "SYNTAX OK"
command -v shellcheck >/dev/null && shellcheck install.sh || echo "(shellcheck not installed — skipped)"
```

Expected: prints `SYNTAX OK`, exit 0.

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add install.sh
git commit -m "Install tmux via Homebrew on macOS when missing"
```

---

## Task 5: Add the zsh block to install.sh

**Files:**
- Modify: `install.sh` (new section 6, inserted between section 5 and section 7)

Installs Oh My Zsh (unattended), the Powerlevel10k theme, zsh-syntax-highlighting, then symlinks the three zsh files via `link_dotfile`. macOS only.

- [ ] **Step 1: Insert the zsh block before the Nerd Font section**

Find this block in `install.sh` (the end of the plugin section followed by the font section header):

```bash
log "Installing tmux plugins via TPM"
"$TPM_DIR/bin/install_plugins" >/dev/null
ok "Plugins installed"

# ── 7. (Optional) install JetBrainsMono Nerd Font for the catppuccin glyphs ──
```

Replace it with:

```bash
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
  else
    ok "zsh-syntax-highlighting already present"
  fi

  # 6d. Symlink the zsh dotfiles (existing real files are backed up timestamped).
  link_dotfile "$DOTFILES_DIR/zsh/zshrc"    "$HOME/.zshrc"
  link_dotfile "$DOTFILES_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"
  link_dotfile "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"
fi

# ── 7. (Optional) install JetBrainsMono Nerd Font for the catppuccin glyphs ──
```

- [ ] **Step 2: Syntax-check**

```bash
cd ~/dotfiles
bash -n install.sh && echo "SYNTAX OK"
command -v shellcheck >/dev/null && shellcheck install.sh || echo "(shellcheck not installed — skipped)"
```

Expected: prints `SYNTAX OK`, exit 0.

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add install.sh
git commit -m "Add zsh environment setup (Oh My Zsh, Powerlevel10k, syntax highlighting)"
```

---

## Task 6: Extend the completion summary with a zsh note

**Files:**
- Modify: `install.sh` (the trailing `cat <<'EOF'` summary block)

- [ ] **Step 1: Append a zsh note after the existing summary heredoc**

Find this block at the end of `install.sh`:

```bash
│  If glyphs in the status bar look broken, your terminal   │
│  font isn't a Nerd Font. Set it in your terminal app      │
│  (Windows Terminal / iTerm2 / gnome-terminal / etc).      │
╰───────────────────────────────────────────────────────────╯
EOF
```

Replace it with:

```bash
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
```

- [ ] **Step 2: Syntax-check**

```bash
cd ~/dotfiles
bash -n install.sh && echo "SYNTAX OK"
command -v shellcheck >/dev/null && shellcheck install.sh || echo "(shellcheck not installed — skipped)"
```

Expected: prints `SYNTAX OK`, exit 0.

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add install.sh
git commit -m "Add zsh note to installer completion summary"
```

---

## Task 7: Update the README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the description line**

Find: `My personal config for tmux and friends. One-line setup on any new Linux/macOS box.`

Replace: `My personal config for zsh and tmux. One-line setup on a new macOS box (the tmux portion also works on Linux).`

- [ ] **Step 2: Add the SSH-key precondition note under Quick install**

Find this block:

```markdown
```bash
git clone git@github.com:tonychung-git/tmux-dotfiles.git ~/dotfiles && ~/dotfiles/install.sh
```

The installer:
```

Replace it with:

```markdown
```bash
git clone git@github.com:tonychung-git/tmux-dotfiles.git ~/dotfiles && ~/dotfiles/install.sh
```

> The clone URL is SSH, so a fresh Mac needs an SSH key registered with GitHub first
> (<https://docs.github.com/en/authentication/connecting-to-github-with-ssh>). No key yet?
> Use the HTTPS URL instead:
> `git clone https://github.com/tonychung-git/tmux-dotfiles.git ~/dotfiles && ~/dotfiles/install.sh`

The installer:
```

- [ ] **Step 3: Replace the numbered installer-steps list**

Find this block:

```markdown
1. Verifies `tmux` is on `PATH`.
2. Backs up an existing `~/.tmux.conf` (timestamped) and symlinks the version in this repo.
3. Clones [TPM](https://github.com/tmux-plugins/tpm) if missing.
4. Installs all plugins declared in `tmux/tmux.conf` (catppuccin theme, yank, vim-tmux-navigator, sensible).
5. *Optionally* downloads JetBrainsMono Nerd Font. Destination depends on OS: `~/.local/share/fonts/` (Linux), `~/Library/Fonts/` (macOS). Skip with `n` if you don't want it.
6. Reloads any running tmux server.
```

Replace it with:

```markdown
1. **macOS:** installs [Homebrew](https://brew.sh) if it's missing.
2. Ensures `tmux` is installed (macOS: installs it via Homebrew; Linux: prompts you to install it and exits).
3. Backs up an existing `~/.tmux.conf` (timestamped) and symlinks the version in this repo.
4. Clones [TPM](https://github.com/tmux-plugins/tpm) if missing.
5. Installs all plugins declared in `tmux/tmux.conf` (catppuccin theme, yank, vim-tmux-navigator, sensible).
6. **macOS:** sets up the zsh environment — [Oh My Zsh](https://ohmyz.sh), the [Powerlevel10k](https://github.com/romkatv/powerlevel10k) theme, and `zsh-syntax-highlighting` — then symlinks `~/.zshrc`, `~/.p10k.zsh`, and `~/.zprofile` from this repo (existing files are backed up timestamped).
7. *Optionally* downloads JetBrainsMono Nerd Font. Destination depends on OS: `~/.local/share/fonts/` (Linux), `~/Library/Fonts/` (macOS). Skip with `n` if you don't want it.
8. Reloads any running tmux server.

The zsh setup targets macOS on Apple Silicon; on Linux the installer does the tmux steps and skips zsh.
```

- [ ] **Step 4: Add `zsh/` to the Layout diagram**

Find this block:

```markdown
```
dotfiles/
├── README.md
├── install.sh
└── tmux/
    └── tmux.conf
```
```

Replace it with:

```markdown
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
```

- [ ] **Step 5: Verify the README still renders sensibly and commit**

```bash
cd ~/dotfiles
grep -nE 'zsh|Homebrew' README.md | head
git add README.md
git commit -m "Document zsh setup in README"
```

Expected: `grep` shows the new zsh/Homebrew mentions across the description, installer list, and Layout.

---

## Task 8: Integration verification — idempotent re-run on this machine

**Files:** none (verification only)

This is the integration test. Note the starting state on this machine: earlier in the session `~/.tmux.conf` and `~/.tmux/` were moved to timestamped backups, while `~/.oh-my-zsh`, `~/.zshrc`, `~/.p10k.zsh`, and `~/.zprofile` are still their original real files. So this run will genuinely set up tmux again and convert the three zsh files into symlinks — backing up the originals (including the one still holding the Cloudflare token) to `*.backup-<timestamp>`. That is expected and correct.

- [ ] **Step 1: Final static checks**

```bash
cd ~/dotfiles
bash -n install.sh && echo "SYNTAX OK"
command -v shellcheck >/dev/null && shellcheck install.sh || echo "(shellcheck not installed — skipped)"
```

Expected: prints `SYNTAX OK`, exit 0.

- [ ] **Step 2: Run the installer**

```bash
cd ~/dotfiles
./install.sh
```

Expected: completes without error (exit 0). Homebrew/Oh My Zsh/Powerlevel10k/zsh-syntax-highlighting all report "already present"; tmux reports its version; TPM is cloned and plugins installed; the three zsh files and `~/.tmux.conf` report `Linked … -> …`; the summary prints with the new `zsh:` note. The Nerd Font step reports a Nerd Font is already installed.

- [ ] **Step 3: Verify all four dotfiles are symlinks into the repo**

```bash
ls -l ~/.tmux.conf ~/.zshrc ~/.p10k.zsh ~/.zprofile
```

Expected: every one is a symlink (`->`) pointing into `/Users/tony-mac-mini/dotfiles/` (`tmux/tmux.conf`, `zsh/zshrc`, `zsh/p10k.zsh`, `zsh/zprofile` respectively).

- [ ] **Step 4: Verify the originals were backed up**

```bash
ls -d ~/.zshrc.backup-* ~/.p10k.zsh.backup-* ~/.zprofile.backup-* 2>/dev/null
grep -l CLOUDFLARE_API_TOKEN ~/.zshrc.backup-* 2>/dev/null
```

Expected: a timestamped backup exists for each; the original `~/.zshrc` backup still contains the `CLOUDFLARE_API_TOKEN` line (proof nothing was lost — it simply did not enter the repo).

- [ ] **Step 5: Re-run to confirm idempotency**

```bash
cd ~/dotfiles
./install.sh
```

Expected: completes without error. This time everything reports "already present" / "Removing existing symlink" then "Linked"; no new `*.backup-*` files are created for the four dotfiles (they are already symlinks, so the helper removes and recreates the symlink rather than backing anything up).

- [ ] **Step 6: Confirm the working tree is clean**

```bash
cd ~/dotfiles
git status --short
git log --oneline origin/main..HEAD 2>/dev/null || git log --oneline -8
```

Expected: `git status` is clean (the `*.backup-*` files live in `$HOME`, not the repo, and `.gitignore` already ignores `*.backup-*` anyway). The log shows the Task 1–7 commits on top of the design-spec commit.

---

## Self-Review

**Spec coverage:**
- Repo structure / `zsh/` folder → Task 1, plus README Layout in Task 7 ✓
- `zsh/zshrc` strips token + `node@22` PATH + `~/.local/bin` PATH, adds nothing → Task 1 Steps 2–3 ✓
- `zsh/p10k.zsh`, `zsh/zprofile` verbatim → Task 1 Step 1 ✓
- install.sh: Homebrew bootstrap → Task 3 ✓
- install.sh: `brew install tmux` on macOS → Task 4 ✓
- install.sh: zsh block (OMZ unattended, p10k clone, zsh-syntax-highlighting, symlink 3 files) → Task 5 ✓
- install.sh: summary extended with zsh note → Task 6 ✓
- Idempotency + timestamped backups → `link_dotfile` helper (Task 2), existence guards in Task 3/5, verified Task 8 ✓
- macOS-only zsh, Linux unchanged → every new block guarded by `[[ "$(uname -s)" == "Darwin" ]]` (Tasks 3–6) ✓
- README updates (description, Layout, zsh section, SSH precondition) → Task 7 ✓
- Testing (bash -n, shellcheck, idempotent re-run, symlink inspection) → per-task checks + Task 8 ✓

**Placeholder scan:** No TBD/TODO; every code step shows the full code or exact command with expected output. ✓

**Type/name consistency:** `link_dotfile` (defined Task 2, used Tasks 2 & 5) — same name and 2-arg signature throughout. `$TS`, `$DOTFILES_DIR`, `$TPM_DIR` are pre-existing install.sh variables; `P10K_DIR` is local to the Task 5 block. Section numbering after Task 3: 1 Homebrew, 2 tmux, 3 tmux.conf, 4 TPM, 5 plugins, 6 zsh, 7 font, 8 reload — consistent across Tasks 3, 5, 6. ✓
