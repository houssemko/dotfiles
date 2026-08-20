function dots --description "Capture dotfile changes with chezmoi and push."
    for dir in (chezmoi managed -i dirs | string match -r '^[^/]+/[^/]+$' | sort -u)
        chezmoi add ~/$dir
    end

    chezmoi re-add
    or return 1

    chezmoi git -- add -A
    or return 1

    if chezmoi git -- diff --cached --quiet 2>/dev/null
        echo "No changes to commit"
    else
        chezmoi git -- commit -m "update configs"
        and chezmoi git -- push
    end
end