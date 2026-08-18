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
    # Parse flags
    set -l dry_run false
    set -l verbose false
    set -l no_git false
    set -l watch false
    set -l debounce 2
    set -l watch_args

    for arg in $argv
        switch $arg
            case --dry-run
                set dry_run true
            case --verbose
                set verbose true
            case --no-git
                set no_git true
            case --watch
                set watch true
            case --debounce
                # Next arg will be the value
            case '*'
                # Check if previous was --debounce
                if test "$argv[(math (string match --index $arg $argv) - 1)]" = "--debounce"
                    set debounce $arg
                else
                    set -a watch_args $arg
                end
        end
    end

    if test "$watch" = "true"
        if not command -q inotifywait
            echo "inotifywait not found. Install inotify-tools: pacman -Sy inotify-tools"
            return 1
        end

        set -l pkg_dirs
        for dir in ~/.dotfiles/*/
            set -l pkg (basename "$dir")
            # Skip .git and scripts packages
            test "$pkg" = ".git"; and continue
            test "$pkg" = "scripts"; and continue
            set -a pkg_dirs $dir
            test -d ~/.config/$pkg; and set -a pkg_dirs ~/.config/$pkg
        end
        test (count $pkg_dirs) -eq 0; and echo "No packages to watch"; and return 1

        set -l watch_cmd "dots-watch --foreground"
        if test "$no_git" = "true"
            set -a watch_cmd --no-git
        end
        if test "$debounce" != "2"
            set -a watch_cmd --debounce $debounce
        end
        set -a watch_cmd $pkg_dirs
        eval $watch_cmd
        return
    end

    set -l sync_cmd "dots-sync"
    if test "$dry_run" = "true"
        set -a sync_cmd --dry-run
    end
    if test "$verbose" = "true"
        set -a sync_cmd --verbose
    end
    if test "$no_git" = "true"
        set -a sync_cmd --no-git
    end
    eval $sync_cmd
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
