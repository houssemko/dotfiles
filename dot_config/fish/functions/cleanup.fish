function cleanup
    set -l orphans (pacman -Qdtq 2>/dev/null)
    if test -n "$orphans"
        sudo pacman -R $orphans
    else
        echo "No orphaned packages"
    end
end