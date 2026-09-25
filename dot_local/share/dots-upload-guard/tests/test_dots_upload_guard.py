#!/usr/bin/env python3
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
GUARD = REPO_ROOT / "dot_local" / "bin" / "executable_dots-upload-guard"


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.base = Path(self.tempdir.name)
        self.repo = self.base / "repo"
        self.repo.mkdir()
        self.run_git("init", "-q")
        self.run_git("config", "user.name", "Test User")
        self.run_git("config", "user.email", "test@example.invalid")
        self.policy = self.base / "policy.json"
        self.write_policy([])

    def tearDown(self):
        self.tempdir.cleanup()

    def run_git(self, *args):
        return subprocess.run(
            ["git", *args],
            cwd=self.repo,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def write_policy(self, approved_paths, binary_hashes=None, denied_globs=None):
        policy = {
            "version": 1,
            "approved_paths": approved_paths,
            "denied_globs": denied_globs or [
                "**/private_*",
                "**/dot_git/**",
                "**/.git/**",
            ],
            "approved_binary_sha256": binary_hashes or {},
            "allow_user_path_globs": [],
        }
        self.policy.write_text(json.dumps(policy), encoding="utf-8")
        self.policy.chmod(0o600)

    def run_guard(self, *args, env=None, input_text=None):
        environment = os.environ.copy()
        if env:
            environment.update(env)
        return subprocess.run(
            [
                "python3",
                str(GUARD),
                "--repo",
                str(self.repo),
                "--policy",
                str(self.policy),
                *args,
            ],
            cwd=self.repo,
            env=environment,
            input=input_text,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def commit(self, message="test"):
        self.run_git("add", "-A")
        self.run_git("commit", "-q", "-m", message)

    def test_missing_policy_fails_closed(self):
        self.policy.unlink()
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("policy", (result.stdout + result.stderr).lower())

    def test_unapproved_path_is_rejected(self):
        self.write_policy(["public.txt"])
        (self.repo / "private.txt").write_text("ordinary text", encoding="utf-8")
        self.run_git("add", "private.txt")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private.txt", result.stdout + result.stderr)

    def test_high_confidence_secret_is_rejected_without_value_echo(self):
        self.write_policy(["config.json"])
        canary = "github_pat_" + ("A" * 36)
        (self.repo / "config.json").write_text(
            json.dumps({"token": canary}), encoding="utf-8"
        )
        self.run_git("add", "config.json")
        result = self.run_guard("--staged")
        combined = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(canary, combined)
        self.assertIn("config.json", combined)

    def test_approved_public_text_passes(self):
        self.write_policy(["public.txt"])
        (self.repo / "public.txt").write_text("safe configuration\n", encoding="utf-8")
        self.run_git("add", "public.txt")
        result = self.run_guard("--staged")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unknown_binary_is_rejected(self):
        self.write_policy(["image.bin"])
        (self.repo / "image.bin").write_bytes(b"\x00\x01\x02binary")
        self.run_git("add", "image.bin")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("binary", (result.stdout + result.stderr).lower())

    def test_approved_binary_hash_passes(self):
        content = b"\x00\x01\x02binary"
        digest = hashlib.sha256(content).hexdigest()
        self.write_policy(["image.bin"], {"image.bin": digest})
        (self.repo / "image.bin").write_bytes(content)
        self.run_git("add", "image.bin")
        result = self.run_guard("--staged")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_private_path_in_old_history_is_rejected(self):
        self.write_policy(["public.txt"])
        (self.repo / "public.txt").write_text("safe\n", encoding="utf-8")
        (self.repo / "private.txt").write_text("old private data\n", encoding="utf-8")
        self.commit("add private data")
        (self.repo / "private.txt").unlink()
        self.commit("remove private data")
        result = self.run_guard("--repository")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private.txt", result.stdout + result.stderr)

    def test_absolute_symlink_is_rejected(self):
        self.write_policy(["link"])
        (self.repo / "link").symlink_to("/home/example/private")
        self.run_git("add", "link")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symlink", (result.stdout + result.stderr).lower())

    def test_malformed_policy_fails_closed(self):
        self.policy.write_text("not-json", encoding="utf-8")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("policy", (result.stdout + result.stderr).lower())

    def test_generic_sensitive_assignment_is_rejected(self):
        self.write_policy(["config.json"])
        (self.repo / "config.json").write_text(
            json.dumps({"password": "real-looking-value"}), encoding="utf-8"
        )
        self.run_git("add", "config.json")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("real-looking-value", result.stdout + result.stderr)

    def test_user_home_path_is_rejected(self):
        self.write_policy(["config.json"])
        (self.repo / "config.json").write_text(
            json.dumps({"path": "/home/alice/private"}), encoding="utf-8"
        )
        self.run_git("add", "config.json")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("user-home-path", result.stdout + result.stderr)

    def test_initialize_policy_creates_outside_repository_policy(self):
        self.policy.unlink()
        (self.repo / "public.txt").write_text("safe\\n", encoding="utf-8")
        self.run_git("add", "public.txt")
        result = self.run_guard("--init-policy", "--accept-baseline")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.policy.exists())
        self.assertEqual(self.policy.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.run_guard("--staged").returncode, 0)

    def test_allow_path_requires_explicit_acceptance(self):
        self.write_policy(["public.txt"])
        candidate = self.repo / "new.txt"
        candidate.write_text("safe\\n", encoding="utf-8")
        result = self.run_guard("--allow-path", str(candidate))
        self.assertNotEqual(result.returncode, 0)
        approved = json.loads(self.policy.read_text(encoding="utf-8"))["approved_paths"]
        self.assertNotIn("new.txt", approved)

    def test_allow_path_adds_reviewed_public_file(self):
        self.write_policy(["public.txt"])
        candidate = self.repo / "new.txt"
        candidate.write_text("safe\\n", encoding="utf-8")
        result = self.run_guard("--allow-path", str(candidate), "--accept-path")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.run_git("add", "new.txt")
        self.assertEqual(self.run_guard("--staged").returncode, 0)

    def test_multiline_private_key_is_rejected(self):
        self.write_policy(["key.txt"])
        key = (
            "-----BEGIN OPENSSH PRIVATE KEY-----\n"
            + ("A" * 64)
            + "\n-----END OPENSSH PRIVATE KEY-----\n"
        )
        (self.repo / "key.txt").write_text(key, encoding="utf-8")
        self.run_git("add", "key.txt")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private-key", result.stdout + result.stderr)

    def test_dollar_in_secret_assignment_is_not_a_placeholder(self):
        self.write_policy(["config.json"])
        (self.repo / "config.json").write_text(
            json.dumps({"password": "real$ecret"}), encoding="utf-8"
        )
        self.run_git("add", "config.json")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("real$ecret", result.stdout + result.stderr)

    def test_token_containing_test_is_not_suppressed(self):
        self.write_policy(["config.txt"])
        canary = "github_pat_test" + ("A" * 32)
        (self.repo / "config.txt").write_text(canary, encoding="utf-8")
        self.run_git("add", "config.txt")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(canary, result.stdout + result.stderr)

    def test_fish_assignment_is_rejected(self):
        self.write_policy(["config.fish"])
        (self.repo / "config.fish").write_text(
            "set -gx API_KEY real-value\\n", encoding="utf-8"
        )
        self.run_git("add", "config.fish")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fish-sensitive-assignment", result.stdout + result.stderr)

    def test_backslash_is_not_a_path_separator(self):
        self.write_policy(["public/name.txt"])
        literal = self.repo / "public\\\\name.txt"
        literal.write_text("safe\\n", encoding="utf-8")
        self.run_git("add", "public\\\\name.txt")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unapproved-path", result.stdout + result.stderr)

    def test_relative_symlink_cannot_escape_repository(self):
        self.write_policy(["link"])
        (self.repo / "link").symlink_to("../outside")
        self.run_git("add", "link")
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("escaping-symlink", result.stdout + result.stderr)

    def test_malformed_denied_glob_fails_closed(self):
        self.write_policy(["public.txt"], denied_globs=["/absolute/*"])
        result = self.run_guard("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsafe denied glob", (result.stdout + result.stderr).lower())

    def test_rev_list_failure_fails_closed(self):
        self.write_policy([])
        self.run_git("commit", "--allow-empty", "-m", "baseline")
        fake_bin = self.base / "bin"
        fake_bin.mkdir()
        real_git = shlex.quote(shutil.which("git") or "/usr/bin/git")
        (fake_bin / "git").write_text(
            f'#!/bin/sh\nif [ "$1" = "rev-list" ]; then exit 42; fi\nexec {real_git} "$@"\n',
            encoding="utf-8",
        )
        (fake_bin / "git").chmod(0o755)
        result = self.run_guard(
            "--repository", env={"PATH": f"{fake_bin}:{os.environ.get('PATH', '')}"}
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("guard-error", (result.stdout + result.stderr).lower())

    def test_commit_message_secret_is_rejected(self):
        self.write_policy([])
        canary = "github_pat_" + ("B" * 36)
        self.run_git("commit", "--allow-empty", "-m", canary)
        result = self.run_guard("--repository")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(canary, result.stdout + result.stderr)

    def test_lightweight_tag_to_blob_is_rejected(self):
        self.write_policy([])
        self.run_git("commit", "--allow-empty", "-m", "baseline")
        blob_file = self.repo / "blob.txt"
        blob_file.write_text("safe\\n", encoding="utf-8")
        blob = self.run_git("hash-object", "-w", "blob.txt").stdout.strip()
        self.run_git("update-ref", "refs/tags/blob-tag", blob)
        result = self.run_guard("--repository")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unpathed-blob", result.stdout + result.stderr)

    def test_annotated_tag_to_blob_is_rejected(self):
        self.write_policy([])
        self.run_git("commit", "--allow-empty", "-m", "baseline")
        blob_file = self.repo / "blob.txt"
        blob_file.write_text("safe\n", encoding="utf-8")
        blob = self.run_git("hash-object", "-w", "blob.txt").stdout.strip()
        self.run_git("tag", "-a", "annotated-blob-tag", blob, "-m", "tag")
        result = self.run_guard("--repository")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unpathed-blob", result.stdout + result.stderr)

    def test_tree_tag_is_scanned(self):
        self.write_policy([])
        self.run_git("commit", "--allow-empty", "-m", "baseline")
        blob_file = self.repo / "blob.txt"
        blob_file.write_text("safe\\n", encoding="utf-8")
        blob = self.run_git("hash-object", "-w", "blob.txt").stdout.strip()
        tree_input = f"100644 blob {blob}\tprivate.txt\n".encode()
        tree = subprocess.run(
            ["git", "mktree"], cwd=self.repo, input=tree_input,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        ).stdout.decode().strip()
        self.run_git("update-ref", "refs/tags/tree-tag", tree)
        result = self.run_guard("--repository")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private.txt", result.stdout + result.stderr)
    def run_capture(self, fake_config, target):
        home = self.base / "capture-home"
        home.mkdir(exist_ok=True)
        policy_dir = home / ".config" / "dots-upload-guard"
        policy_dir.mkdir(parents=True, exist_ok=True)
        (policy_dir / "policy.json").write_text(
            json.dumps({
                "version": 1,
                "approved_paths": [],
                "denied_globs": ["**/private_*"],
                "approved_binary_sha256": {},
                "allow_user_path_globs": [],
            }),
            encoding="utf-8",
        )
        (policy_dir / "policy.json").chmod(0o600)
        guard_dir = home / ".local" / "bin"
        guard_dir.mkdir(parents=True, exist_ok=True)
        guard_target = guard_dir / "dots-upload-guard"
        shutil.copy2(GUARD, guard_target)
        guard_target.chmod(0o755)
        fake_bin = home / "bin"
        fake_bin.mkdir(exist_ok=True)
        marker = home / "add-called"
        fake_chezmoi = fake_bin / "chezmoi"
        fake_chezmoi.write_text(
            "#!/bin/sh\n"
            "if [ \"$1\" = \"cat-config\" ]; then\n"
            f"  printf '%b\\n' '{fake_config}'\n"
            "  exit 0\n"
            "fi\n"
            "if [ \"$1\" = \"add\" ]; then touch \"$CAPTURE_MARKER\"; exit 0; fi\n"
            "exit 0\n",
            encoding="utf-8",
        )
        fake_chezmoi.chmod(0o755)
        env = os.environ.copy()
        env.update({
            "HOME": str(home),
            "PATH": f"{fake_bin}:{env.get('PATH', '')}",
            "CAPTURE_MARKER": str(marker),
        })
        command = (
            f"source {shlex.quote(str(REPO_ROOT / 'dot_config/fish/functions/dots-capture.fish'))}; "
            f"dots-capture {shlex.quote(str(target))}"
        )
        return subprocess.run(
            ["fish", "-c", command], cwd=self.repo, env=env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        ), marker

    def test_target_outside_public_config_root_is_rejected(self):
        self.write_policy([])
        target = self.base / "outside.txt"
        target.write_text("safe\n", encoding="utf-8")
        result = self.run_guard(
            "--check-target", str(target), "--target-root", str(self.base)
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("target-outside-public-root", result.stdout + result.stderr)

    def test_common_credential_filename_is_rejected_before_capture(self):
        self.write_policy([])
        target = self.base / ".config" / ".netrc"
        target.parent.mkdir(parents=True)
        target.write_text("machine login user\n", encoding="utf-8")
        result = self.run_guard(
            "--check-target", str(target), "--target-root", str(self.base)
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("denied-target", result.stdout + result.stderr)

    def test_push_input_blob_is_scanned_even_without_a_ref(self):
        self.write_policy([])
        blob_file = self.base / "push-blob.txt"
        blob_file.write_text("safe\n", encoding="utf-8")
        blob = self.run_git("hash-object", "-w", str(blob_file)).stdout.strip()
        push_input = f"refs/heads/main {blob} refs/heads/main {'0' * 40}\n"
        result = self.run_guard(
            "--repository", "--push-oids", input_text=push_input
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unpathed-blob", result.stdout + result.stderr)

    def test_capture_refuses_auto_push_configuration(self):
        target = self.base / "capture-target.txt"
        target.write_text("safe\n", encoding="utf-8")
        result, marker = self.run_capture(
            "sourceDir = \\\"~/.dotfiles\\\"\\n[git]\\nautoCommit = true\\nautoPush = true",
            target,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(marker.exists())

    def test_capture_rejects_symlink_target(self):
        target_real = self.base / "capture-real.txt"
        target_real.write_text("private\n", encoding="utf-8")
        target = self.base / "capture-link.txt"
        target.symlink_to(target_real)
        result, marker = self.run_capture(
            "sourceDir = \\\"~/.dotfiles\\\"\\n[git]\\nautoCommit = false\\nautoPush = false",
            target,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symlink", (result.stdout + result.stderr).lower())
        self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
