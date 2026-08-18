source /usr/share/cachyos-fish-config/cachyos-config.fish

# Abbreviations
abbr wt curl wttr.in/Monastir
abbr ve pacman -Qs
abbr ff fastfetch
abbr se paru -Ss

function cl
    paru -Scc
    sudo find /var/cache/pacman/pkg -name 'download-*' -delete 2>/dev/null
end

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

function dots --description "Sync dotfiles and push to remote. Use 'dots --watch' for live watching."
    argparse 'dry-run' 'verbose' 'no-git' 'watch' 'debounce=' -- $argv
    or return 1

    set -l debounce
    if set -q _flag_debounce
        set debounce $_flag_debounce
    else
        set debounce 2
    end

    if set -q _flag_watch
        if not command -q inotifywait
            echo "inotifywait not found. Install inotify-tools: pacman -Sy inotify-tools"
            return 1
        end

        set -l pkg_dirs
        for dir in ~/.dotfiles/*/
            set -l pkg (basename "$dir")
            contains -- "$pkg" .git scripts; and continue
            set -a pkg_dirs $dir
            test -d ~/.config/$pkg; and set -a pkg_dirs ~/.config/$pkg
        end

        if test (count $pkg_dirs) -eq 0
            echo "No packages to watch"
            return 1
        end

        set -l extra_args
        set -q _flag_no_git; and set -a extra_args --no-git
        test "$debounce" != 2; and set -a extra_args --debounce $debounce

        dots-watch --foreground $extra_args $pkg_dirs
        return
    end

    set -l sync_args
    set -q _flag_dry_run; and set -a sync_args --dry-run
    set -q _flag_verbose; and set -a sync_args --verbose
    set -q _flag_no_git; and set -a sync_args --no-git

    dots-sync $sync_args
end

# System update
function up 
    function _up_header -a text
        set_color --bold cyan
        echo -e "\n==> $text"
        set_color normal
    end

    _up_header "Updating System & AUR Packages"
    if command -q paru
        paru -Syu --noconfirm
    else
        echo "paru not found, falling back to pacman..."
        sudo pacman -Syu --noconfirm
    end

    if command -q flatpak
        _up_header "Updating Flatpaks"
        flatpak update -y
    end
    
    _up_header "Checking for .pacnew / .pacsave files"
    set -l pacnew_files (find /etc -type f -name "*.pacnew" -o -name "*.pacsave" 2>/dev/null)
    if test -n "$pacnew_files"
        set_color yellow
        echo "Warning: Configuration files require merging:"
        for file in $pacnew_files
            echo "  -> $file"
        end
        set_color normal
    else
        echo "No configuration files require merging."
    end

    _up_header "Checking for Failed Systemd Services"
    set -l failed_services (systemctl --failed --plain --no-legend)
    if test -n "$failed_services"
        set_color red
        echo "Warning: The following services have failed:"
        systemctl --failed
        set_color normal
    else
        set_color green
        echo "All systemd services are running normally."
        set_color normal
    end

    echo "----------------------------------------"
    set_color --bold green
    echo "✔ System update complete!"
    set_color normal
end

# Get the fastest mirrors
function uac --description "Update Chaotic-AUR mirrorlist and refresh repository"
    # Pre-authorize sudo
    if not sudo -v
        echo "Sudo authentication failed."
        return 1
    end

    set -l tmpfile (mktemp)

    echo "==> Rating Chaotic-AUR mirrors..."
    if rate-mirrors --save=$tmpfile --disable-comments-in-file --allow-root --protocol https --per-mirror-timeout 1500 chaotic-aur
        echo "==> Backing up and updating chaotic-mirrorlist..."
        sudo mv /etc/pacman.d/chaotic-mirrorlist /etc/pacman.d/chaotic-mirrorlist-backup
        sudo mv $tmpfile /etc/pacman.d/chaotic-mirrorlist
        
        # Clean caches if the command exists/aliased
        if functions -q ua-drop-caches; or alias -q ua-drop-caches
            ua-drop-caches
        end

        echo "==> Syncing database..."
        paru -Sy --noconfirm
        echo "✔ Chaotic-AUR mirrorlist updated successfully!"
    else
        echo "❌ rate-mirrors failed. Mirrorlist unchanged."
        rm -f $tmpfile
        return 1
    end
end

# Cleanup local orphaned packages
function cleanup
    set -l orphans (pacman -Qdtq 2>/dev/null)
    if test -n "$orphans"
        sudo pacman -R $orphans
    else
        echo "No orphaned packages"
    end
end
      
# Use fd as the default fzf command
set -x FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'

# Added by Antigravity CLI installer
set -gx PATH "/home/houssem/.local/bin" $PATH

# Secrets live outside the synced dotfiles (see ~/.config/fish-secrets.fish)
test -f ~/.config/fish-secrets.fish; and source ~/.config/fish-secrets.fish
