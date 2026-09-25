function dots --description "Review and push already-captured public dotfile changes."
    argparse -n dots 'y/yes' -- $argv
    or return 1
    if test (count $argv) -gt 0
        echo "dots: usage: dots [-y|--yes]" >&2
        return 1
    end
    set -l repo (git rev-parse --show-toplevel 2>/dev/null)
    if not set -q repo[1]
        if test -e "$HOME/.dotfiles/.git"
            set repo "$HOME/.dotfiles"
        else
            echo "dots: not inside a Git repository" >&2
            return 1
        end
    end

    set -l guard $HOME/.local/bin/dots-upload-guard
    set -l policy $HOME/.config/dots-upload-guard/policy.json
    if not test -x $guard
        echo "dots: missing immutable upload guard: $guard" >&2
        return 1
    end
    if not test -f $policy
        echo "dots: initialize $policy with --accept-baseline first" >&2
        return 1
    end
    set -l chezmoi_config (chezmoi cat-config 2>/dev/null)
    if not string match -q -r '(?i)autoCommit\s*=\s*false' -- "$chezmoi_config" \
        or not string match -q -r '(?i)autoPush\s*=\s*false' -- "$chezmoi_config"
        echo "dots: chezmoi autoCommit and autoPush must both be false" >&2
        return 1
    end

    # Keep the guard active for ordinary commits and pushes from this clone.
    git -C $repo config core.hooksPath .githooks
    or return 1

    # Validated one-button capture: per-file guard checks before mutation.
    # Phase 1 validates all home targets with zero mutation; Phase 2 re-adds
    # validated targets only. Hooks, binaries, new paths abort to manual dots-capture.
    set -l untracked (git -C $repo ls-files --others --exclude-standard)
    if test (count $untracked) -gt 0
        echo "dots: untracked files require explicit review; nothing was staged" >&2
        printf '  %s\n' $untracked >&2
        return 1
    end

    if type -q chezmoi
        set -l cstatus (chezmoi status 2>/dev/null)
        if test (count $cstatus) -gt 20
            echo "dots: too many home changes; capture explicitly, e.g. dots-capture ~/.config/path/to/file" >&2
            return 1
        end
        if test (count $cstatus) -gt 0
            set -l validated_targets
            set -l validated_sources
            set -l skipped_auto
            for line in $cstatus
                set -l fields (string split -n ' ' -- $line)
                if test (count $fields) -lt 2
                    set -a skipped_auto "$line (unparseable)"
                    continue
                end
                set -l rel $fields[-1]
                if not string match -q -- '.config/*' $rel
                    set -a skipped_auto "$rel (outside auto root)"
                    continue
                end
                set -l target "$HOME/$rel"
                if test -L "$target"
                    set -a skipped_auto "$rel (symlink)"
                    continue
                end
                set -l cursor (dirname "$target")
                set -l bad_ancestor 0
                while test "$cursor" != /; and test "$cursor" != "$HOME"
                    if test -L "$cursor"
                        set bad_ancestor 1
                        break
                    end
                    set cursor (dirname "$cursor")
                end
                if test $bad_ancestor -eq 1
                    set -a skipped_auto "$rel (symlinked ancestor)"
                    continue
                end
                if not test -f "$target"
                    set -a skipped_auto "$rel (not a regular file)"
                    continue
                end
                set -l gout (python3 $guard --repo $repo --policy $policy --check-target "$target" --target-root "$HOME" 2>&1)
                or begin
                    if string match -q -- '*guard-error*' $gout
                        printf '%s\n' $gout >&2
                        return 1
                    end
                    set -a skipped_auto "$rel (needs explicit review)"
                    continue
                end
                set -l src (chezmoi source-path -- "$target" 2>/dev/null)
                if not set -q src[1]
                    set -a skipped_auto "$rel (unmanaged or ignored)"
                    continue
                end
                set -l src_candidate $src[1]
                if not string match -q -r '^/' -- "$src_candidate"
                    set src_candidate "$repo/$src_candidate"
                end
                set -l src_abs (realpath -- "$src_candidate" 2>/dev/null)
                set -l src_rel (realpath --relative-to="$repo" -- "$src_abs" 2>/dev/null)
                if test -z "$src_abs"; or test -z "$src_rel"; or string match -q -r '^\.\./' -- "$src_rel"
                    set -a skipped_auto "$rel (source outside repo)"
                    continue
                end
                if string match -q -- '.githooks/*' "$src_rel"; or test "$src_rel" = .githooks
                    set -a skipped_auto "$rel (hooks need explicit review)"
                    continue
                end
                set -l pout (python3 $guard --repo $repo --policy $policy --check-path "$repo/$src_rel" 2>&1)
                or begin
                    if string match -q -- '*guard-error*' $pout
                        printf '%s\n' $pout >&2
                        return 1
                    end
                    set -a skipped_auto "$rel (needs allowlist review)"
                    continue
                end
                set -a validated_targets "$target"
                set -a validated_sources "$repo/$src_rel"
            end
            set -l idx 1
            for target in $validated_targets
                set -l src $validated_sources[$idx]
                set idx (math $idx + 1)
                chezmoi re-add -- "$target"
                or return 1
                set -l cout (python3 $guard --repo $repo --policy $policy --check-path "$src" 2>&1)
                or begin
                    printf '%s\n' $cout >&2
                    return 1
                end
                git -C $repo add -- "$src"
                or return 1
            end
            if test (count $skipped_auto) -gt 0
                echo "dots: auto-captured $(count $validated_targets); skipped needing explicit dots-capture:" >&2
                printf '  %s\n' $skipped_auto >&2
            end
        end
    end

    # Stage remaining tracked modifications except hooks. Hooks never auto-stage.
    git -C $repo add -u -- . ':!.githooks'
    or return 1
    set -l hook_dirty (git -C $repo status --porcelain -- .githooks 2>/dev/null)
    if test (count $hook_dirty) -gt 0
        git -C $repo reset -q
        echo "dots: .githooks changes need explicit review; nothing was committed" >&2
        return 1
    end

    python3 $guard --repo $repo --policy $policy --staged
    or return 1

    if git -C $repo diff --cached --quiet 2>/dev/null
        echo "No public changes to commit"
        # Read-only hint: home may differ from source until explicit capture.
        # Never runs re-add; best-effort only.
        if type -q chezmoi
            set -l cstatus (chezmoi status 2>/dev/null)
            if test (count $cstatus) -gt 0
                echo "home differs from source (requires explicit capture):"
                set -l shown 0
                for line in $cstatus
                    set shown (math $shown + 1)
                    if test $shown -gt 20
                        echo "  ... (truncated, run: chezmoi status)"
                        break
                    end
                    echo "  $line"
                end
                echo "review with: chezmoi diff"
                echo "capture one file with, e.g.:"
                set -l suggested 0
                for line in $cstatus
                    set suggested (math $suggested + 1)
                    if test $suggested -gt 5
                        break
                    end
                    set -l fields (string split -n ' ' -- $line)
                    if test (count $fields) -ge 2
                        echo "  dots-capture ~/$fields[-1]"
                    end
                end
            end
        end
        return 0
    end

    git -C $repo diff --cached --stat
    if set -q _flag_yes
        echo "dots: --yes: pushing without prompt"
    else
        set -l answer
        read -P "Push these reviewed public changes? [y/N] " answer
        if test "$answer" != y; and test "$answer" != Y
            echo "dots: push cancelled; staged changes were left for inspection"
            return 0
        end
    end

    git -C $repo commit -m "chore: update public configs"
    or return 1
    python3 $guard --repo $repo --policy $policy --repository
    or return 1
    git -C $repo push
end
