function dots-capture --description "Capture one explicitly reviewed public target."
    if test (count $argv) -eq 0
        echo "usage: dots-capture ~/.config/path/to/public-file" >&2
        return 1
    end

    set -l repo (git rev-parse --show-toplevel 2>/dev/null)
    or begin
        echo "dots-capture: not inside a Git repository" >&2
        return 1
    end
    set -l guard $repo/dot_local/bin/dots-upload-guard
    set -l policy $HOME/.config/dots-upload-guard/policy.json
    if not test -x $guard; or not test -f $policy
        echo "dots-capture: guard or local policy is unavailable" >&2
        return 1
    end

    for target in $argv
        set -l target_path (realpath -- "$target" 2>/dev/null)
        or begin
            echo "dots-capture: target does not exist: $target" >&2
            return 1
        end
        if test -d "$target_path"
            echo "dots-capture: directories are not accepted; review files individually" >&2
            return 1
        end

        set -l source_path (chezmoi source-path -- "$target_path" 2>/dev/null)
        if not set -q source_path[1]
            set -l answer
            read -P "Add this target to the public source? [y/N] " answer
            if test "$answer" != y; and test "$answer" != Y
                return 0
            end
            chezmoi add --new -- "$target_path"
            or return 1
            set source_path (chezmoi source-path -- "$target_path" 2>/dev/null)
        end
        if not set -q source_path[1]
            echo "dots-capture: target is ignored or cannot be mapped" >&2
            return 1
        end
        if string match -q -- "$repo/*" "$source_path[1]"
            set source_path[1] "$repo/$source_path[1]"
        end

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

        git -C $repo add -- "$source_path[1]"
        or return 1
        python3 $guard --repo $repo --policy $policy --staged
        or return 1
    end
end
