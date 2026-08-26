function up --description 'Update system and check maintenance (topgrade-style)'
    set -l start (date +%s)
    set -g _up_names
    set -g _up_status

    # Message helpers, styled after topgrade
    # https://github.com/topgrade-rs/topgrade

    function _up_rule -a color msg
        if test (count $msg) -gt 0
            set -l len (string length -- "$msg")
            set -l pad (math "30 - $len")
            test $pad -lt 1; and set pad 1
            echo (set_color $color)"── "$msg" "(string repeat --max $pad '─')(set_color normal)
        else
            echo (set_color $color)(string repeat --max 30 '─')(set_color normal)
        end
    end

    function _up_next -a color name
        set -g _up_started 1
        _up_rule $color $name
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

    if command -q flatpak
        _up_next blue Flatpak
        if flatpak update -y
            _up_ok 'Flatpaks updated'
            _up_track Flatpak OK
        else
            _up_fail 'Flatpak update failed'
            _up_track Flatpak FAILED
        end
    else
        _up_track Flatpak SKIPPED
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
    else
        _up_track Services SKIPPED
    end

    # Summary
    set -l elapsed (math (date +%s) - $start)'s'
    _up_next green "Summary ($elapsed)"
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

    functions -e _up_rule _up_next _up_mark \
        _up_ok _up_warn _up_fail _up_item _up_track
    set -e _up_names _up_status _up_started
end
