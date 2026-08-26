function cleanup --description 'Remove local orphaned packages'
    if pacman -Qdtq >/dev/null 2>&1
        while pacman -Qdtq >/dev/null 2>&1
            sudo pacman -Rns (pacman -Qdtq)
            if test $status -ne 0
                break
            end
        end
    else
        echo "No orphan packages found."
    end
end
