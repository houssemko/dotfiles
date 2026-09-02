source /usr/share/cachyos-fish-config/cachyos-config.fish

# Abbreviations
abbr wt curl wttr.in/Monastir
abbr ve pacman -Qs
abbr ff fastfetch
abbr se paru -Ss

abbr in sudo pacman -Sy
abbr ins paru -Sy --noconfirm
abbr rem sudo pacman -Runs
abbr gpu sudo intel_gpu_top
abbr bl sudo systemctl restart bluetooth
abbr mic sudo micro
abbr mi micro
abbr e exit
abbr p s-tui
abbr merge ffmpeg -f concat -i file.txt -c copy merged.mp4
abbr z zoxide 
abbr gc git clone 
abbr fi flatpak install
abbr fu flatpak uninstall

# Use fd as the default fzf command
set -x FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
