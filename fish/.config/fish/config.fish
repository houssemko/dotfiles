source /usr/share/cachyos-fish-config/cachyos-config.fish

# Abbreviations
abbr rm trash 
abbr wt curl wttr.in/Monastir
abbr ve pacman -Qs
abbr ff fastfetch
abbr se paru -Ss

function cl
    paru -Scc
    sudo find /var/cache/pacman/pkg -name 'download-*' -delete 2>/dev/null
end

# abbr up paru -Syu --noconfirm
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
# abbr fu flatpak update

function dots
    git -C ~/.dotfiles add -A
    git -C ~/.dotfiles commit -m "update configs"
    git -C ~/.dotfiles push
end

function up
    echo "paru -Syu --noconfirm"
    paru -Syu --noconfirm
    echo "
flatpak update"
    flatpak update -y
end

# Get the fastest mirrors
alias ua-drop-caches='sudo paccache -rk3; paru -Scc --aur --noconfirm'
alias uac 'sudo true; and \
    set TMPFILE (mktemp); and \
    rate-mirrors --save=$TMPFILE --disable-comments-in-file --allow-root --protocol https  --per-mirror-timeout 850 --top-mirrors-number-to-retest 10  arch --completion=1 \
        && sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-backup \
        && sudo mv $TMPFILE /etc/pacman.d/mirrorlist \
    && \
    set TMPFILE (mktemp); and \
    rate-mirrors --save=$TMPFILE --disable-comments-in-file --allow-root --protocol https --per-mirror-timeout 1500  chaotic-aur \
        && sudo mv /etc/pacman.d/chaotic-mirrorlist /etc/pacman.d/chaotic-mirrorlist-backup \
        && sudo mv $TMPFILE /etc/pacman.d/chaotic-mirrorlist \
    && \
    ua-drop-caches && paru -Syyu --noconfirm'
    
# Cleanup local orphaned packages
function cleanup 
    while pacman -Qdtq --noconfirm
        sudo pacman -R (pacman -Qdtq)
    end
end
      
# Use fd as the default fzf command
set -x FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'

# Added by Antigravity CLI installer
set -gx PATH "/home/houssem/.local/bin" $PATH
