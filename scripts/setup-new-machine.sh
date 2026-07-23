#!/usr/bin/env bash
#
# setup-new-machine.sh — one-shot bootstrap for Ronald's dev Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/nkap360/nyami-dotfiles/main/scripts/setup-new-machine.sh | bash
#
# Idempotent: safe to re-run.

set -euo pipefail

log()  { printf "\n\033[1;36m▸\033[0m %s\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m⚠\033[0m %s\n" "$*"; }
die()  { printf "\n\033[31m✗ %s\033[0m\n" "$*"; exit 1; }

# ─── 0. Preconditions ────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || die "This script is macOS-only"

# ─── 1. Homebrew ─────────────────────────────────────────────────
log "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # ARM Homebrew path
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
fi
ok "brew $(brew --version | head -1)"

# ─── 2. Dependencies ─────────────────────────────────────────────
log "Installing CLI dependencies via brew"
BREW_PKGS=(
  gh                     # GitHub CLI
  cloudflare-wrangler2   # Wrangler (Cloudflare Workers)
  node                   # Node LTS
  pnpm                   # Fast package manager
  uv                     # Python package manager (Astral)
  age                    # Encryption for sops
  sops                   # Secrets Operations (Mozilla)
  jq                     # JSON processor
  ripgrep                # Fast grep
  fd                     # Fast find
)

for pkg in "${BREW_PKGS[@]}"; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    ok "$pkg already installed"
  else
    printf "  → installing %s ... " "$pkg"
    brew install "$pkg" >/dev/null 2>&1 && echo "✓" || warn "$pkg install failed"
  fi
done

# Doppler CLI (separate tap)
if ! command -v doppler >/dev/null 2>&1; then
  log "Installing Doppler CLI"
  brew install dopplerhq/cli/doppler
fi
ok "doppler $(doppler --version 2>&1)"

# ─── 3. Age private key ──────────────────────────────────────────
log "Age private key (needed to decrypt nyami-secrets-vault)"

AGE_KEY_HOME="$HOME/.config/age/nyami.key"
SOPS_KEY_XDG="$HOME/.config/sops/age/keys.txt"
SOPS_KEY_MAC="$HOME/Library/Application Support/sops/age/keys.txt"

mkdir -p "$(dirname "$AGE_KEY_HOME")" \
         "$(dirname "$SOPS_KEY_XDG")" \
         "$(dirname "$SOPS_KEY_MAC")"

if [[ -f "$AGE_KEY_HOME" ]]; then
  ok "age key already at $AGE_KEY_HOME"
else
  warn "No age key at $AGE_KEY_HOME"
  echo ""
  echo "  Copy the private key (all 3 lines: '# created:', '# public key:', 'AGE-SECRET-KEY-1...')"
  echo "  from your password manager (Bitwarden / 1Password / macOS Keychain)"
  echo "  into: $AGE_KEY_HOME"
  echo ""
  read -r -p "  Press ENTER when the file exists ..."
  [[ -f "$AGE_KEY_HOME" ]] || die "Still not found. Aborting."
fi
chmod 400 "$AGE_KEY_HOME"

# Mirror to sops default paths (macOS has two possible locations)
cp -f "$AGE_KEY_HOME" "$SOPS_KEY_XDG" && chmod 400 "$SOPS_KEY_XDG"
cp -f "$AGE_KEY_HOME" "$SOPS_KEY_MAC" && chmod 400 "$SOPS_KEY_MAC"
ok "sops can find the key on macOS + Linux paths"

# ─── 4. Auth: GitHub, Doppler, Cloudflare ────────────────────────
log "GitHub CLI auth"
if gh auth status >/dev/null 2>&1; then
  ok "already logged in ($(gh api user --jq .login))"
else
  gh auth login --hostname github.com --git-protocol https --web
fi

log "Doppler login"
if doppler whoami >/dev/null 2>&1; then
  ok "already logged in"
else
  doppler login
fi

log "Cloudflare Wrangler login (optional — for deploys)"
if ! wrangler whoami 2>&1 | grep -q "You are logged in"; then
  echo "  (skip if you don't need to deploy from this machine)"
  read -r -p "  Log in to Cloudflare now? [Y/n] " ans
  if [[ ! "$ans" =~ ^[Nn] ]]; then
    wrangler login
  fi
else
  ok "wrangler logged in"
fi

# ─── 5. Clone repos ──────────────────────────────────────────────
log "Cloning core repos to ~/Downloads"
mkdir -p "$HOME/Downloads"
cd "$HOME/Downloads"

REPOS=(
  nkap360/nyami-agentic-portfolio
  nkap360/alphapilot
  nkap360/bpsi_website
  nkap360/nyami-secrets-vault
  nkap360/nyami-dotfiles
)
for repo in "${REPOS[@]}"; do
  name="${repo##*/}"
  if [[ -d "$name/.git" ]]; then
    ok "$name already cloned"
  else
    echo "  → cloning $repo"
    gh repo clone "$repo" "$name" 2>&1 | grep -v "^Cloning" || true
  fi
done

# ─── 6. Optional: decrypt the vault to seed ~/.config/nyami ──────
log "Decrypt vault to ~/.config/nyami (optional)"
if [[ -d "$HOME/Downloads/nyami-secrets-vault/.git" ]]; then
  cd "$HOME/Downloads/nyami-secrets-vault"
  echo "  Run 'make decrypt-all' to seed ~/.config/nyami/*.env from the vault?"
  read -r -p "  [Y/n] " ans
  if [[ ! "$ans" =~ ^[Nn] ]]; then
    make decrypt-all
  fi
fi

# ─── 7. Summary ──────────────────────────────────────────────────
log "All set."
echo ""
echo "  Tools:"
for cmd in brew gh doppler wrangler sops age node pnpm; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "    \033[32m✓\033[0m %s\n" "$cmd"
  else
    printf "    \033[31m✗\033[0m %s (missing)\n" "$cmd"
  fi
done
echo ""
echo "  Next: cd into a project and 'doppler setup' to link it to the right Doppler config."
echo "        Then: doppler run -- pnpm dev  (or your dev command)"
echo ""
