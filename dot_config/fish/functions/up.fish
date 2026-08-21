function up
    function _up_sep
        set_color --bold blue
        echo "────────────────────────────────────────────"
        set_color normal
    end

    function _up_header -a text
        set_color normal
        echo
        _up_sep
        set_color --bold cyan
        echo "  $text"
        set_color normal
        _up_sep
    end

    function _up_ok -a msg
        set_color --bold green
        echo "  ✔ $msg"
        set_color normal
    end

    function _up_warn -a msg
        set_color --bold yellow
        echo "  ⚠ $msg"
        set_color normal
    end

    function _up_fail -a msg
        set_color --bold red
        echo "  ✖ $msg"
        set_color normal
    end

    function _up_info -a msg
        set_color --bold white
        echo "  $msg"
        set_color normal
    end

    set -l start (date +%s)
    _up_header "Updating System & AUR Packages"

    if command -q paru
        paru -Syu --noconfirm; and _up_ok "Packages updated (paru)"
        or _up_fail "Package update failed"
    else if command -q yay
        yay -Syu --noconfirm; and _up_ok "Packages updated (yay)"
        or _up_fail "Package update failed"
    else if command -q pacman
        _up_warn "No AUR helper found, falling back to pacman"
        sudo pacman -Syu --noconfirm; and _up_ok "Packages updated (pacman)"
        or _up_fail "Package update failed"
    else
        _up_fail "No package manager found!"
    end

    if command -q flatpak
        _up_header "Updating Flatpaks"
        flatpak update -y; and _up_ok "Flatpaks updated"
        or _up_warn "Flatpak update had issues"
    end

    _up_header "Checking for .pacnew / .pacsave files"
    set -l pacnew_files (find /etc -type f \( -name "*.pacnew" -o -name "*.pacsave" \) 2>/dev/null)
    if test -n "$pacnew_files"
        _up_warn (count $pacnew_files)" config files need attention:"
        for file in $pacnew_files
            set_color yellow
            echo "     -> $file"
            set_color normal
        end
    else
        _up_ok "No configuration files require merging"
    end

    _up_header "Checking for Failed Systemd Services"
    if command -q systemctl
        if systemctl --failed --plain --no-legend | string length -q
            _up_fail "Failed services detected:"
            systemctl --failed
        else
            _up_ok "All systemd services are running normally"
        end
    else
        _up_info "systemctl not available, skipping"
    end

    set -l duration (math (date +%s) - $start)
    echo
    _up_sep
    set_color --bold green
    echo "  ✔ System update complete in {$duration}s"
    set_color normal
    _up_sep
    echo

    functions -e _up_sep _up_header _up_ok _up_warn _up_fail _up_info
end
