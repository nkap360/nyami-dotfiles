# nyami-dotfiles

Bootstrap public pour un nouveau Mac de Ronald.

## One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/nkap360/nyami-dotfiles/main/scripts/setup-new-machine.sh | bash
```

Ce que le script installe :

- **Homebrew** (si absent)
- **CLI** : `gh`, `doppler`, `wrangler`, `node`, `pnpm`, `uv`, `age`, `sops`, `jq`, `ripgrep`, `fd`
- **Age private key** : demande de coller la clé depuis ton password manager
- **Login** : `gh`, `doppler`, `wrangler` (optionnel)
- **Clone** : `nyami-agentic-portfolio`, `alphapilot`, `bpsi_website`, `nyami-secrets-vault`, `nyami-dotfiles`
- **Décryptage vault** (optionnel) : `make decrypt-all` pour seed `~/.config/nyami/`

## Ce que ce repo NE contient PAS

- Aucun secret, aucun `.env`, aucune clé privée.
- Rien qui pose problème si le repo est public.

## Rappel : la clé age privée est stockée en dehors de git

- Le fichier `~/.config/age/nyami.key` ne doit **jamais** être commité.
- Backup dans Bitwarden / 1Password / macOS Keychain.
- Sans elle, le vault `nyami-secrets-vault` est irrécupérable.
