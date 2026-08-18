# dotfiles

My personal config files managed with [chezmoi](https://www.chezmoi.io/).

## Apps

| App | Description |
|-----|-------------|
| ghostty | Terminal emulator |
| fastfetch | System info |
| cava | Audio visualizer |
| btop | System monitor |
| fish | Shell |
| mpv | Media player |
| niri | Wayland compositor |
| yay | AUR helper |
| paru | AUR helper |

## Install

```bash
chezmoi init --apply https://github.com/houssemko/dotfiles.git
```

## Daily operations

```bash
dots                  # capture changes and push (same as: chezmoi re-add && git commit && git push)
chezmoi apply         # apply the source state to this machine
chezmoi update        # pull the latest source and apply
chezmoi cd            # jump into the source dir
```

## Layout

The source dir follows chezmoi conventions:

| Source | Target |
|--------|--------|
| `dot_config/fish/config.fish` | `~/.config/fish/config.fish` |
| `dot_config/fish/private_fish_variables` | `~/.config/fish/fish_variables` (mode 600) |