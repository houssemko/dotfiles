#!/usr/bin/env python3
import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
GUARD = REPO_ROOT / "dot_local" / "bin" / "dots-upload-guard"


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

    def run_guard(self, *args):
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


if __name__ == "__main__":
    unittest.main()
