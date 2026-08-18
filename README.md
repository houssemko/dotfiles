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
| `dots` | Capture changes and push (see below) |
| `chezmoi apply` | Apply the source state to this machine |
| `chezmoi edit <file>` | Edit a file in the source dir |
| `chezmoi update` | Pull the latest source and apply |
| `chezmoi cd` | Jump into the source dir |

### `dots`

Defined in `~/.config/fish/config.fish`. Runs `chezmoi re-add`, then commits and pushes
via `chezmoi git` (skips the commit when there is nothing to commit).

## Layout

The source dir follows chezmoi conventions:

| Source | Target |
|--------|--------|
| `dot_config/fish/config.fish` | `~/.config/fish/config.fish` |
| `dot_config/fish/private_fish_variables` | `~/.config/fish/fish_variables` (mode 600) |

Repo-only files (not managed by chezmoi): `README.md`, `.gitignore`, `.chezmoiignore`.