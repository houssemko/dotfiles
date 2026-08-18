#!/usr/bin/env bash
# Shared dotfiles sync library

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
LOG_FILE="${LOG_FILE:-$DOTFILES_DIR/watcher.log}"
LOCK_FILE="${LOCK_FILE:-/tmp/dots-sync.lock}"

GIT_CONFIG_VALIDATED=0

log() {
    local msg="[$(date '+%H:%M:%S')] $1"
    echo "$msg"
    echo "$msg" >>"$LOG_FILE" 2>/dev/null || true
}

# Validate git config (cached)
validate_git_config() {
    [[ $GIT_CONFIG_VALIDATED -eq 1 ]] && return 0
    if ! git -C "$DOTFILES_DIR" config user.name >/dev/null 2>&1; then
        log "ERROR: git user.name not set in $DOTFILES_DIR"
        return 1
    fi
    if ! git -C "$DOTFILES_DIR" config user.email >/dev/null 2>&1; then
        log "ERROR: git user.email not set in $DOTFILES_DIR"
        return 1
    fi
    GIT_CONFIG_VALIDATED=1
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
    local pkg_dir
    for pkg_dir in "$DOTFILES_DIR"/*/; do
        [[ "$(basename "$pkg_dir")" == ".git" ]] && continue
        [[ "$(basename "$pkg_dir")" == "scripts" ]] && continue
        pkg=$(basename "$pkg_dir")
        local stow_out
        if ! stow_out=$(stow -d "$DOTFILES_DIR" --target "$HOME" "$pkg" 2>&1); then
            log "WARNING: stow conflict for $pkg: $stow_out"
        fi
    done
}

sync_config_to_dotfiles() {
    local pkg src dst
    local pkg_dir
    for pkg_dir in "$DOTFILES_DIR"/*/; do
        [[ "$(basename "$pkg_dir")" == ".git" ]] && continue
        [[ "$(basename "$pkg_dir")" == "scripts" ]] && continue
        pkg=$(basename "$pkg_dir")
        src="$HOME/.config/$pkg"
        dst="$DOTFILES_DIR/$pkg/.config/$pkg"
        [[ -d "$src" ]] || continue
        mkdir -p "$dst"
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
    local file_count
    file_count=$(git -C "$DOTFILES_DIR" diff --cached --name-only | wc -l)
    git -C "$DOTFILES_DIR" commit -m "update configs ($file_count files)" >/dev/null
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
    local dry_run="${DRY_RUN:-0}"
    local no_git="${NO_GIT:-0}"
    local verbose="${VERBOSE:-0}"

    acquire_lock || return 1
    log "Starting sync..."
    sync_config_to_dotfiles
    if [[ $no_git -eq 0 ]]; then
        if [[ $dry_run -eq 1 ]]; then
            log "DRY RUN: would commit and push"
        else
            git_sync_and_push || log "Push failed, will still recreate symlinks"
        fi
    else
        log "Skipping git (--no-git)"
    fi
    if [[ $dry_run -eq 0 ]]; then
        recreate_symlinks
    else
        log "DRY RUN: would recreate symlinks"
    fi
    release_lock
    log "Sync complete"
    return 0
}

# Export functions for sourcing
export -f log acquire_lock release_lock recreate_symlinks sync_config_to_dotfiles git_sync_and_push full_sync validate_git_config