# dotfiles

My personal config files managed with [chezmoi](https://www.chezmoi.io/).

## Apps

| App | Description |
|-----|-------------|
| btop | System monitor |
| cava | Audio visualizer |
| fastfetch | System info |
| fish | Shell |
| ghostty | Terminal emulator |
| mpv | Media player |
| niri | Wayland compositor |
| opencode | AI coding assistant |
| paru | AUR helper |
| vivaldi | Browser (config only) |
| yay | AUR helper |

## Install

```bash
chezmoi init --apply https://github.com/houssemko/dotfiles.git
```

## Daily operations

| Command | Description |
|---------|-------------|
| `dots-capture <file>` | Explicitly review and capture one public target |
| `dots` | Review, commit, and push already-captured public changes |
| `chezmoi apply` | Apply the source state to this machine |
| `chezmoi edit <file>` | Edit a file in the source dir |
| `chezmoi update` | Pull the latest source and apply |
| `chezmoi cd` | Jump into the source dir |

### `dots`

`dots` is deliberately fail-closed for the public repository:

- It never runs broad `chezmoi re-add`; use `dots-capture <file>` for an explicit,
  reviewed public target.
- It refuses untracked files and stages only already-approved tracked paths.
- It runs the local `dots-upload-guard` against the complete Git index and all
  local refs before commit/push.
- It asks for confirmation before committing and pushing.
- ChezMoi automatic commits and pushes are disabled.

The trusted public allowlist lives outside the repository at
`~/.config/dots-upload-guard/policy.json` and must be initialized explicitly:

```bash
python3 ~/.local/bin/dots-upload-guard --repo ~/.dotfiles --init-policy --accept-baseline
```

The guard is accident prevention, not an absolute boundary: a deliberate
`git push --no-verify`, a different clone without the guard, or a manually edited
local policy can bypass it. Do not put private files in this public repository;
use a private repository or secret manager for those files.

## Layout

The source dir follows chezmoi conventions:

| Source | Target |
|--------|--------|
| `dot_config/fish/config.fish` | `~/.config/fish/config.fish` |
| `dot_local/bin/dots-upload-guard` | `~/.local/bin/dots-upload-guard` |

`private_fish_variables`, OpenCode service/session state, credentials, and nested
Git metadata are local-only and must not be added to the public source.

Repo-only files (not managed by chezmoi): `README.md`, `.gitignore`, `.chezmoiignore`.