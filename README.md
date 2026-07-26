# dotfiles

My personal config files managed with [GNU Stow](https://www.gnu.org/software/stow/).

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
git clone https://github.com/<your-username>/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Stow everything
stow */

# Or stow individual apps
stow ghostty
stow fish
stow mpv
```

## Update

```bash
cd ~/dotfiles
stow -R */    # restow all
```

## Unstow

```bash
cd ~/dotfiles
stow -D */    # remove all symlinks
```
