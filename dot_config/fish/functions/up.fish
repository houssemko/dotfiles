function up
    function _up_header -a text
        set_color brblack
        echo "╭────────────────────────────────────────────────────"
        set_color --bold cyan
        echo "│ $text"
        set_color brblack
        echo "╰────────────────────────────────────────────────────"
        set_color normal
    end

    function _up_ok -a msg
        set_color --bold green
        echo "  ✓"
        set_color normal
        echo " $msg"
    end

    function _up_warn -a msg
        set_color --bold yellow
        echo "  !"
        set_color normal
        echo " $msg"
    end

    function _up_fail -a msg
        set_color --bold red
        echo "  ✗"
        set_color normal
        echo " $msg"
    end

    function _up_info -a msg
        set_color --bold blue
        echo "  •"
        set_color normal
        echo " $msg"
    end

    function _up_item -a msg
        set_color brblack
        echo "    └─"
        set_color normal
        echo " $msg"
    end

    set -l start (date +%s)

    set_color --bold cyan
    echo
    echo "╭────────────────────────────────────────────────────╮"
    echo "│ SYSTEM UPDATE                                      │"
    echo "╰────────────────────────────────────────────────────╯"
    set_color normal

    _up_header "System & AUR Packages"

    if command -q paru
        _up_info "Using paru..."
        paru -Syu --noconfirm
        if test $status -eq 0
            _up_ok "Packages updated successfully"
        else
            _up_fail "Package update failed"
        end
    else if command -q yay
        _up_info "Using yay..."
        yay -Syu --noconfirm
        if test $status -eq 0
            _up_ok "Packages updated successfully"
        else
            _up_fail "Package update failed"
        end
    else if command -q pacman
        _up_warn "No AUR helper — using pacman"
        sudo pacman -Syu --noconfirm
        if test $status -eq 0
            _up_ok "Packages updated successfully"
        else
            _up_fail "Package update failed"
        end
    else
        _up_fail "No supported package manager found"
    end

    if command -q flatpak
        _up_header "Flatpak"
        flatpak update -y
        if test $status -eq 0
            _up_ok "Flatpaks updated successfully"
        else
            _up_warn "Flatpak update completed with issues"
        end
    end

    _up_header "Configuration Files"

    set -l pacnew_files (find /etc -type f \( \
        -name "*.pacnew" -o \
        -name "*.pacsave" \
    \) 2>/dev/null)

    if test (count $pacnew_files) -gt 0
        _up_warn (count $pacnew_files)" file(s) need attention"
        for file in $pacnew_files
            _up_item $file
        end
    else
        _up_ok "No .pacnew or .pacsave files found"
    end

    _up_header "Systemd Services"

    if command -q systemctl
        if systemctl --failed --plain --no-legend | string length -q
            _up_fail "Failed services detected"
            systemctl --failed
        else
            _up_ok "All services are running normally"
        end
    else
        _up_info "systemctl not available — skipping"
    end

    set -l duration (math (date +%s) - $start)

    set_color brblack
    echo "────────────────────────────────────────────────────"
    set_color --bold green
    echo "  ✓ Update complete"
    set_color normal
    echo "    └─ "$duration"s"
    echo

    functions -e _up_header _up_ok _up_warn _up_fail _up_info _up_item
end
