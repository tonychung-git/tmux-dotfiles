# Spec：擴充 ~/dotfiles，讓全新 macOS 一行指令設定好 zsh + tmux

**日期：** 2026-05-14
**狀態：** 設計已核可

## 目的

在一台全新、乾淨的 Mac 上，用單一指令：

```bash
git clone git@github.com:tonychung-git/tmux-dotfiles.git ~/dotfiles && ~/dotfiles/install.sh
```

同時設定好 tmux 環境（目前已能運作）與 zsh 環境 —— Oh My Zsh + Powerlevel10k 主題 + zsh-syntax-highlighting + Nerd Font —— 讓 shell 的外觀與行為跟擁有者目前這台機器一致。

## 範圍

**納入範圍：**

- 把 zsh 設定加進現有的 dotfiles repo
- macOS 上偵測不到 Homebrew 時自動安裝
- macOS 上偵測不到 tmux 時自動安裝

**明確排除：**

- 目前 `~/.zshrc` 裡「不屬於 zsh/tmux 設定本身」的內容 —— 具體指 `CLOUDFLARE_API_TOKEN` export、`node@22` PATH export、`~/.local/bin` PATH export，這三段一律從進版控的 `zshrc` 中移除。
- 不建立 `~/.zshrc.local`（或任何其他）「個人覆寫」機制 —— YAGNI。
- zsh 部分不支援 Linux。tmux 部分維持現有的跨平台行為；zsh 區塊只在 macOS 執行，Linux 上跳過。
- zsh 設定以 **Apple Silicon Mac** 為目標。`zsh/zshrc` 與 `zsh/zprofile` 沿用 `/opt/homebrew` 路徑（原樣複製擁有者設定的必然結果），Intel Mac（Homebrew 在 `/usr/local`）不在支援範圍。
- 不變更登入 shell（`chsh`）—— macOS 預設已是 zsh。
- 不管理、不輪換使用者的機密。

## 做法

採方案 A —— 維持 repo 刻意保持的扁平結構，擴充單一 `install.sh`。符合 repo 既有理念（README：「extend install.sh with another symlink step」）。已否決：拆成多支 per-tool 腳本（B）、引入 Stow/chezmoi 等 dotfiles 管理器（C）—— 對只有兩個工具的 repo 而言皆屬不必要。

## 擴充後的 repo 結構

```
dotfiles/
├── README.md           # 更新：提及 zsh、Layout 加入 zsh/、註明 SSH 金鑰前提
├── install.sh          # 擴充（見下方流程）
├── .gitignore          # 不動
├── tmux/
│   └── tmux.conf       # 不動
└── zsh/
    ├── zshrc           # 通用版 .zshrc —— 只含 OMZ 模板 + p10k + syntax-highlighting
    ├── p10k.zsh        # 原樣複製擁有者的 ~/.p10k.zsh（已設定好的外觀）
    └── zprofile        # eval "$(brew shellenv)" —— 讓 brew 安裝的 tmux 執行檔進入 PATH 所必需
```

## `zsh/zshrc` 的內容

從目前的 `~/.zshrc` 衍生，**保留**：

- Powerlevel10k instant-prompt 區塊
- `export ZSH="$HOME/.oh-my-zsh"`
- `ZSH_THEME="powerlevel10k/powerlevel10k"`
- `plugins=(git)`
- `source $ZSH/oh-my-zsh.sh`
- `[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh`
- `source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh`
- Oh My Zsh 模板註解（無害，本身就是檔案的說明文件）

**移除**（不屬於 zsh/tmux 設定）：

- `export CLOUDFLARE_API_TOKEN=...`
- `export PATH="/opt/homebrew/opt/node@22/bin:$PATH"`
- `export PATH="$HOME/.local/bin:$PATH"`

檔案結尾不新增任何內容。

## install.sh 流程

單一腳本，以 `uname` 判斷作業系統。zsh 區塊只在 macOS（Darwin）執行；Linux 上跳過，現有行為不變。

| # | 步驟 | 狀態 |
|---|------|------|
| 1 | **Bootstrap Homebrew** —— 在 Darwin 上，若找不到 `brew`，執行官方 Homebrew 安裝腳本，接著 `eval "$(brew shellenv)"` 讓本次執行後續步驟可用 | 新增 |
| 2 | **確保 tmux** —— 在 Darwin 上，若 `tmux` 不存在則 `brew install tmux`；Linux 上維持既有「請自行安裝」訊息 | 修改 |
| 3 | symlink `~/.tmux.conf` → repo | 既有 |
| 4 | 安裝 TPM | 既有 |
| 5 | 透過 TPM 安裝 tmux 外掛 | 既有 |
| 6 | **zsh 區塊（僅 Darwin）：** | 新增 |
| | 6a. 若 `~/.oh-my-zsh` 不存在則安裝 Oh My Zsh —— unattended 模式：`RUNZSH=no CHSH=no KEEP_ZSHRC=yes` | |
| | 6b. 若 `~/.oh-my-zsh/custom/themes/powerlevel10k` 不存在則 clone Powerlevel10k（`--depth 1`） | |
| | 6c. 若尚未安裝則 `brew install zsh-syntax-highlighting` | |
| | 6d. symlink `~/.zshrc`、`~/.p10k.zsh`、`~/.zprofile` → repo，沿用既有的時間戳備份機制 | |
| 7 | 安裝 JetBrainsMono Nerd Font（tmux 的 catppuccin 與 p10k 皆需要） | 既有 |
| 8 | 若有執行中的 tmux server 則 reload | 既有 |
| 9 | 印出完成摘要 —— 補上 zsh 提示（「開新終端機或執行 `exec zsh`」） | 修改 |

## Idempotency 與安全性

- 每個步驟都有存在性檢查；重複執行安全且不具破壞性。
- symlink 前，既有的「真實檔案」會移到時間戳備份（`<file>.backup-YYYYMMDD-HHMMSS`）；既有的 symlink 則移除後重建。
- `set -euo pipefail` 已在腳本中。
- Oh My Zsh 以 `KEEP_ZSHRC=yes` 安裝，不會碰 zshrc；且 repo 的 `zshrc` 無論如何都在 OMZ 步驟「之後」才 symlink，因此 repo 版本永遠勝出（並備份原本的檔案）。
- instant-prompt 區塊的快取檔在首次執行時不存在 —— 既有的 `[[ -r ... ]]` 防呆已處理。

## 已知前提與風險

- **SSH 金鑰**：clone 指令使用 SSH URL（`git@github.com:...`），全新 Mac 必須已將 SSH 金鑰註冊到 GitHub。此事在裝縼器控制範圍外 —— README 會註明，並提及 HTTPS URL 作為替代。
- **Homebrew bootstrap** 會要求 sudo 密碼並安裝 Xcode Command Line Tools —— 屬互動式、可能耗時數分鐘。README 會註明。
- 目前的 `~/.zshrc` 含明文 `CLOUDFLARE_API_TOKEN`。本設計已將其排除於 repo 之外，但由於該 token 已被揭露，擁有者可能會想另行輪換。

## 測試

沒有可供測試的全新 Mac，因此採務實驗證：

- `bash -n install.sh` 語法檢查；若有 `shellcheck` 則執行 `shellcheck install.sh`。
- 在目前這台機器重新執行 `install.sh`：因其具 idempotency，應偵測到所有東西皆已存在、不做任何破壞性變更；最終狀態為各受管 dotfile 皆為指向 repo 的 symlink。
- 手動確認 `~/.zshrc`、`~/.p10k.zsh`、`~/.zprofile` 皆為指向 `~/dotfiles/zsh/` 的 symlink。

## README 更新（最小幅度）

- 更新標題／說明行，提及 zsh，而非只有 tmux。
- 在「Layout」圖中加入 `zsh/`。
- 新增一小節說明 zsh 設定會安裝什麼（Homebrew bootstrap、Oh My Zsh、Powerlevel10k、zsh-syntax-highlighting）。
- 註明 clone 指令的 SSH 金鑰前提。
- 保留既有的 keymap cheatsheet 與字型／SSH 指引。
