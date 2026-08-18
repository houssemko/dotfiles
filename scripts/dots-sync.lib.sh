#!/usr/bin/env bash
# Shared dotfiles sync library

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
LOG_FILE="${LOG_FILE:-$DOTFILES_DIR/watcher.log}"
LOCK_FILE="${LOCK_FILE:-$DOTFILES_DIR/.sync.lock}"

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Validate git config
validate_git_config() {
    if ! git -C "$DOTFILES_DIR" config user.name >/dev/null 2>&1; then
        log "ERROR: git user.name not set in $DOTFILES_DIR"
        return 1
    fi
    if ! git -C "$DOTFILES_DIR" config user.email >/dev/null 2>&1; then
        log "ERROR: git user.email not set in $DOTFILES_DIR"
        return 1
    fi
    return 0
}

# Acquire exclusive lock with timeout (default 30s)
acquire_lock() {
    local timeout="${1:-30}"
    exec 9>"$LOCK_FILE"
    if ! flock -w "$timeout" 9; then
        log "Could not acquire lock after ${timeout}s (another sync running?)"
        return 1
    fi
}

release_lock() {
    flock -u 9 2>/dev/null || true
    exec 9>&- 2>/dev/null || true
    rm -f "$LOCK_FILE" 2>/dev/null || true
}

recreate_symlinks() {
    local pkg
    for pkg_dir in "$DOTFILES_DIR"/*/; do
        [[ "$(basename "$pkg_dir")" == ".git" ]] && continue
        [[ "$(basename "$pkg_dir")" == "scripts" ]] && continue
        pkg=$(basename "$pkg_dir")
        stow -d "$DOTFILES_DIR" --target "$HOME" "$pkg" 2>/dev/null || true
    done
}

sync_config_to_dotfiles() {
    local pkg src dst
    for pkg_dir in "$DOTFILES_DIR"/*/; do
        [[ "$(basename "$pkg_dir")" == ".git" ]] && continue
        [[ "$(basename "$pkg_dir")" == "scripts" ]] && continue
        pkg=$(basename "$pkg_dir")
        src="$HOME/.config/$pkg"
        dst="$DOTFILES_DIR/$pkg/.config/$pkg"
        [[ -d "$src" ]] || continue
        mkdir -p "$dst"
        # Use rsync for incremental sync + deletion of removed files
        rsync -a --delete "$src/" "$dst/" 2>/dev/null || true
    done
}

git_sync_and_push() {
    validate_git_config || return 1
    git -C "$DOTFILES_DIR" add -A
    if git -C "$DOTFILES_DIR" diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi
    git -C "$DOTFILES_DIR" commit -m "update configs" >/dev/null
    if git -C "$DOTFILES_DIR" pull --rebase --autostash 2>/dev/null && \
       git -C "$DOTFILES_DIR" push 2>&1; then
        log "Configs updated and pushed"
    else
        log "Commit created, push failed (run 'git pull' in $DOTFILES_DIR)"
        return 1
    fi
}

# Full sync cycle: sync -> git -> stow
# Returns 0 on success, 1 on failure
full_sync() {
    acquire_lock || return 1
    log "Starting sync..."
    sync_config_to_dotfiles
    git_sync_and_push
    local git_rc=$?
    recreate_symlinks
    release_lock
    log "Sync complete"
    return $git_rc
}

# Export functions for sourcing
export -f log acquire_lock release_lock recreate_symlinks sync_config_to_dotfiles git_sync_and_push full_sync validate_git_config