function cl
    paru -Scc
    sudo find /var/cache/pacman/pkg -name 'download-*' -delete 2>/dev/null
end