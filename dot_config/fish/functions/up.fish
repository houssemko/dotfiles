function up --description 'Update system and check maintenance (topgrade-style)'
    set -l start (date +%s)
    set -g _up_names
    set -g _up_status

    # Message helpers, styled after topgrade
    # https://github.com/topgrade-rs/topgrade

    function _up_rule -a color
        echo (set_color $color)(string repeat --max 20 '─')(set_color normal)
    end

    function _up_header -a color msg
        echo (set_color $color)'── '(set_color --bold)$msg(set_color normal)
    end

    function _up_next -a color name
        set -q _up_started; and echo
        set -g _up_started 1
        _up_header $color $name
    end

    function _up_mark -a color sym msg
        echo (set_color $color)"  $sym"(set_color normal)" $msg"
    end

    function _up_ok -a msg
        _up_mark green ✓ $msg
    end

    function _up_warn -a msg
        _up_mark yellow ! $msg
    end

    function _up_fail -a msg
        _up_mark red ✗ $msg >&2
    end

    function _up_item -a msg
        echo "    "$msg
    end

    function _up_track -a name state
        set -a _up_names $name
        set -a _up_status $state
    end

    # Detect AUR helper (paru > yay > pikaur > pacman)
    set -l helper
    for h in paru yay pikaur
        command -q $h; and set helper $h; and break
    end

    _up_next cyan Packages
    if test -n "$helper"
        if $helper -Syu --noconfirm
            _up_ok "Packages updated ($helper)"
            _up_track Packages OK
        else
            _up_fail 'Package update failed'
            _up_track Packages FAILED
        end
    else if command -q pacman
        _up_warn 'No AUR helper found, updating with pacman'
        if sudo pacman -Syu --noconfirm
            _up_ok 'Packages updated'
            _up_track Packages OK
        else
            _up_fail 'Package update failed'
            _up_track Packages FAILED
        end
    else
        _up_fail 'No supported package manager found'
        _up_track Packages FAILED
    end
    _up_rule cyan

    if command -q flatpak
        _up_next blue Flatpak
        if flatpak update -y
            _up_ok 'Flatpaks updated'
            _up_track Flatpak OK
        else
            _up_fail 'Flatpak update failed'
            _up_track Flatpak FAILED
        end
        _up_rule blue
    else
        _up_track Flatpak SKIPPED
    end

    if command -q tealdeer; or command -q tldr
        _up_next brgreen tldr
        set -l updated 0
        if command -q tealdeer
            tealdeer update; and set updated 1
        else
            tldr --update; and set updated 1
        end
        if test $updated -eq 1
            _up_ok 'Pages updated'
            _up_track tldr OK
        else
            _up_fail 'tldr update failed'
            _up_track tldr FAILED
        end
        _up_rule brgreen
    else
        _up_track tldr SKIPPED
    end

    _up_next magenta 'Configuration files'
    set -l pacnew (find /etc -type f \
        \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null)

    if test (count $pacnew) -gt 0
        _up_warn (count $pacnew)" file(s) need attention (sudo pacdiff)"
        _up_item $pacnew
        _up_track Configuration WARNED
    else
        _up_ok 'No .pacnew or .pacsave files found'
        _up_track Configuration OK
    end
    _up_rule magenta

    if command -q systemctl
        _up_next yellow 'Systemd services'
        if systemctl --failed --plain --no-legend | string length -q
            _up_fail 'Failed services detected:'
            systemctl --failed
            _up_track Services FAILED
        else
            _up_ok 'All services are running normally'
            _up_track Services OK
        end
        _up_rule yellow
    else
        _up_track Services SKIPPED
    end

    # Summary
    _up_next green Summary
    for i in (seq (count $_up_names))
        switch $_up_status[$i]
            case OK
                _up_mark green ✓ $_up_names[$i]
            case FAILED
                _up_mark red ✗ $_up_names[$i]
            case WARNED
                _up_mark yellow ! $_up_names[$i]
            case SKIPPED
                _up_mark brblack · $_up_names[$i]
        end
    end
    _up_item (math (date +%s) - $start)'s'
    _up_rule green

    functions -e _up_rule _up_header _up_next _up_mark \
        _up_ok _up_warn _up_fail _up_item _up_track
    set -e _up_names _up_status _up_started
end
