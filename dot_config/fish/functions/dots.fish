function dots --description "Capture dotfile changes with chezmoi and push."
    echo "󰏗 Re-adding dotfiles..."
    chezmoi re-add; or return 1

    echo "󰐕 Staging changes..."
    chezmoi git -- add -A; or return 1

    if chezmoi git -- diff --cached --quiet
        echo "✓ No changes"
        return 0
    end

    echo "󰜘 Committing..."
    chezmoi git -- commit -m "update configs"; or return 1

    echo "󰒰 Pushing..."
    chezmoi git -- push; or return 1

    echo "✓ Done"
end
