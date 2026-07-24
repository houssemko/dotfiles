#!/bin/bash
# Restore GNOME extension settings from dotfiles
# Usage: bash restore.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Restoring GNOME extension settings..."

# Load extension settings
if [ -f "$SCRIPT_DIR/extensions-dconf.conf" ]; then
    dconf load /org/gnome/shell/extensions/ < "$SCRIPT_DIR/extensions-dconf.conf"
    echo "Extension settings restored."
fi

# Load shell settings
if [ -f "$SCRIPT_DIR/shell-settings.conf" ]; then
    dconf load /org/gnome/shell/ < "$SCRIPT_DIR/shell-settings.conf"
    echo "Shell settings restored."
fi

# Enable extensions
if [ -f "$SCRIPT_DIR/enabled-extensions.txt" ]; then
    EXTENSIONS=$(cat "$SCRIPT_DIR/enabled-extensions.txt" | tr '\n' ',' | sed 's/,$//')
    dconf write /org/gnome/shell/enabled-extensions "[$EXTENSIONS]"
    echo "Extensions enabled."
fi

echo "Done! You may need to restart GNOME Shell (Alt+F2, type 'r', press Enter) or log out and back in."
