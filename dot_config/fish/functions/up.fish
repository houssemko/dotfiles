function up --description 'Update the system and check maintenance tasks (topgrade-style)'
    set -l start (date +%s)
    set -g _up_n 0
    set -g _up_names
    set -g _up_status

    # Message helpers, styled after topgrade
    # https://github.com/topgrade-rs/topgrade
    function _up_header -a color msg
        set -l w 80
        test -n "$COLUMNS"; and set w $COLUMNS
        set -l fill (math $w - (string length -- "$msg") - 4)
        test $fill -ge 0; or set fill 0
        echo (set_color $color)'── '(set_color normal)(set_color --bold)$msg(set_color normal)' '(set_color $color)(string repeat --max $fill '─')(set_color normal)
    end

    function _up_next -a name
        set -g _up_n (math $_up_n + 1)
        _up_header brblack "$_up_n: $name"
    end

    function _up_ok -a msg
        echo (set_color green)'  ✓'(set_color normal)" $msg"
    end

    function _up_warn -a msg
        echo (set_color yellow)'  !'(set_color normal)" $msg"
    end

    function _up_fail -a msg
        echo (set_color red)'  ✗'(set_color normal)" $msg" >&2
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
        if command -q $h
            set helper $h
            break
        end
    end

    _up_next 'Packages'
    if test -n "$helper"
        if $helper -Syu --noconfirm
            _up_ok "Packages updated successfully ($helper)"
            _up_track 'Packages' OK
        else
            _up_fail 'Package update failed'
            _up_track 'Packages' FAILED
        end
    else if command -q pacman
        _up_warn 'No AUR helper found, updating with pacman'
        if sudo pacman -Syu --noconfirm
            _up_ok 'Packages updated successfully'
            _up_track 'Packages' OK
        else
            _up_fail 'Package update failed'
            _up_track 'Packages' FAILED
        end
    else
        _up_fail 'No supported package manager found'
        _up_track 'Packages' FAILED
    end

    if command -q flatpak
        _up_next 'Flatpak'
        if flatpak update -y
            _up_ok 'Flatpaks updated successfully'
            _up_track 'Flatpak' OK
        else
            _up_fail 'Flatpak update failed'
            _up_track 'Flatpak' FAILED
        end
    else
        _up_track 'Flatpak' SKIPPED
    end

    _up_next 'Configuration files'
    set -l pacnew_files (find /etc -type f \( \
        -name "*.pacnew" -o \
        -name "*.pacsave" \
    \) 2>/dev/null)

    if test (count $pacnew_files) -gt 0
        _up_warn (count $pacnew_files)" file(s) need attention (run 'sudo pacdiff')"
        for file in $pacnew_files
            _up_item $file
        end
        _up_track 'Configuration' WARNED
    else
        _up_ok 'No .pacnew or .pacsave files found'
        _up_track 'Configuration' OK
    end

    if command -q systemctl
        _up_next 'Systemd services'
        if systemctl --failed --plain --no-legend | string length -q
            _up_fail 'Failed services detected:'
            systemctl --failed
            _up_track 'Services' FAILED
        else
            _up_ok 'All services are running normally'
            _up_track 'Services' OK
        end
    else
        _up_track 'Services' SKIPPED
    end

    # Summary
    echo
    _up_header brblack 'Summary'
    for i in (seq (count $_up_names))
        switch $_up_status[$i]
            case OK
                echo (set_color green)'  ✓'(set_color normal)' '$_up_names[$i]
            case FAILED
                echo (set_color red)'  ✗'(set_color normal)' '$_up_names[$i]
            case WARNED
                echo (set_color yellow)'  !'(set_color normal)' '$_up_names[$i]
            case SKIPPED
                echo (set_color brblack)'  ·'(set_color normal)' '$_up_names[$i]
        end
    end
    _up_item (math (date +%s) - $start)'s'

    functions -e _up_header _up_next _up_ok _up_warn _up_fail _up_item _up_track
    set -e _up_n
    set -e _up_names
    set -e _up_status
end
