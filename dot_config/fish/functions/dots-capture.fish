function dots-capture --description "Capture one explicitly reviewed public target."
    if test (count $argv) -eq 0
        echo "usage: dots-capture ~/.config/path/to/public-file" >&2
        return 1
    end

    set -l repo (git rev-parse --show-toplevel 2>/dev/null)
    if not set -q repo[1]
        if test -e "$HOME/.dotfiles/.git"
            set repo "$HOME/.dotfiles"
        else
            echo "dots-capture: not inside a Git repository" >&2
            return 1
        end
    end
    set -l guard $HOME/.local/bin/dots-upload-guard
    set -l policy $HOME/.config/dots-upload-guard/policy.json
    if not test -x $guard; or not test -f $policy
        echo "dots-capture: immutable guard or local policy is unavailable" >&2
        return 1
    end
    set -l chezmoi_config (chezmoi cat-config 2>/dev/null)
    if not string match -q -r '(?i)autoCommit\s*=\s*false' -- "$chezmoi_config" \
        or not string match -q -r '(?i)autoPush\s*=\s*false' -- "$chezmoi_config"
        echo "dots-capture: chezmoi autoCommit and autoPush must both be false" >&2
        return 1
    end

    for target in $argv
        set -l lexical_target (string replace -r '^~' "$HOME" "$target")
        if not string match -q -r '^/' "$lexical_target"
            set lexical_target (pwd)/$lexical_target
        end
        if test -L "$lexical_target"
            echo "dots-capture: symlink targets are not accepted: $target" >&2
            return 1
        end
        set -l cursor (dirname "$lexical_target")
        while test "$cursor" != /; and test "$cursor" != "$HOME"
            if test -L "$cursor"
                echo "dots-capture: symlinked ancestors are not accepted: $target" >&2
                return 1
            end
            set cursor (dirname "$cursor")
        end
        set -l target_path (realpath -- "$lexical_target" 2>/dev/null)
        or begin
            echo "dots-capture: target does not exist: $target" >&2
            return 1
        end
        if test -d "$target_path"
            echo "dots-capture: directories are not accepted; review files individually" >&2
            return 1
        end
        python3 $guard --repo $repo --policy $policy \
            --check-target "$target_path" --target-root "$HOME"
        or return 1

        set -l source_path (chezmoi source-path -- "$target_path" 2>/dev/null)
        if not set -q source_path[1]
            set -l answer
            read -P "Add this target to the public source? [y/N] " answer
            if test "$answer" != y; and test "$answer" != Y
                return 0
            end
            chezmoi add --new --secrets=error -- "$target_path"
            or return 1
            set source_path (chezmoi source-path -- "$target_path" 2>/dev/null)
        end
        if not set -q source_path[1]
            echo "dots-capture: target is ignored or cannot be mapped" >&2
            return 1
        end
        set -l source_candidate $source_path[1]
        if not string match -q -r '^/' "$source_candidate"
            set source_candidate "$repo/$source_candidate"
        end
        set -l source_absolute (realpath -- "$source_candidate" 2>/dev/null)
        set -l source_relative (realpath --relative-to="$repo" -- "$source_absolute" 2>/dev/null)
        if test -z "$source_absolute"; or test -z "$source_relative"; or string match -q -r '^\.\./' "$source_relative"
            echo "dots-capture: source is outside the repository" >&2
            return 1
        end
        set source_path[1] "$repo/$source_relative"

        if not python3 $guard --repo $repo --policy $policy --check-path "$source_path[1]"
            set -l answer
            read -P "Approve this reviewed file in the local public allowlist? [y/N] " answer
            if test "$answer" != y; and test "$answer" != Y
                echo "dots-capture: source was not approved or staged" >&2
                return 1
            end
            python3 $guard --repo $repo --policy $policy \
                --allow-path "$source_path[1]" --accept-path
            or return 1
        end

        chezmoi re-add -- "$target_path"
        or return 1
        python3 $guard --repo $repo --policy $policy --check-path "$source_path[1]"
        or return 1

        git -C $repo add -- "$source_path[1]"
        or return 1
        python3 $guard --repo $repo --policy $policy --staged
        or return 1
    end
end
