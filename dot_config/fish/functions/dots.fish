function dots --description "Review and push already-captured public dotfile changes."
    set -l repo (git rev-parse --show-toplevel 2>/dev/null)
    if not set -q repo[1]
        if test -e "$HOME/.dotfiles/.git"
            set repo "$HOME/.dotfiles"
        else
            echo "dots: not inside a Git repository" >&2
            return 1
        end
    end

    set -l guard $repo/dot_local/bin/dots-upload-guard
    set -l policy $HOME/.config/dots-upload-guard/policy.json
    if not test -x $guard
        echo "dots: missing upload guard: $guard" >&2
        return 1
    end
    if not test -f $policy
        echo "dots: initialize $policy with --accept-baseline first" >&2
        return 1
    end

    # Keep the guard active for ordinary commits and pushes from this clone.
    git -C $repo config core.hooksPath .githooks
    or return 1

    # chezmoi re-add is intentionally not run implicitly.  Use an explicit
    # target review first; a broad re-add can copy private home files back into
    # the public source tree.
    set -l untracked (git -C $repo ls-files --others --exclude-standard)
    if test (count $untracked) -gt 0
        echo "dots: untracked files require explicit review; nothing was staged" >&2
        printf '  %s\n' $untracked >&2
        return 1
    end

    # Stage only changes to already-approved tracked paths.  New files remain
    # untracked until a separate, explicit policy review adds them locally.
    git -C $repo add -u -- .
    or return 1

    python3 $guard --repo $repo --policy $policy --staged
    or return 1

    if git -C $repo diff --cached --quiet 2>/dev/null
        echo "No public changes to commit"
        return 0
    end

    git -C $repo diff --cached --stat
    set -l answer
    read -P "Push these reviewed public changes? [y/N] " answer
    if test "$answer" != y; and test "$answer" != Y
        echo "dots: push cancelled; staged changes were left for inspection"
        return 0
    end

    git -C $repo commit -m "chore: update public configs"
    or return 1
    python3 $guard --repo $repo --policy $policy --repository
    or return 1
    git -C $repo push
end
