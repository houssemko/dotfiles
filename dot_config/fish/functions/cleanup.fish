function cleanup --description 'Remove orphan packages'
    set -l orphans (pacman -Qtdq)
    if test -n "$orphans"
        sudo pacman -Rns $orphans
    else
        echo "Nothing to clean."
    end
end
