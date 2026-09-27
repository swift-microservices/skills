"""Exercise releases against local Git remotes and a fake GitHub CLI, without network access."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
MANIFESTS = (".claude-plugin/plugin.json", ".codex-plugin/plugin.json")
FAKE_GH = '''#!/usr/bin/env python3
import json, os, pathlib, sys
path = pathlib.Path(os.environ["FAKE_GH_STATE"])
state = json.loads(path.read_text())
args = sys.argv[1:]
state.setdefault("calls", []).append(args)
path.write_text(json.dumps(state))
if args[0] == "api":
    if args[-1].endswith("/releases/latest"):
        print(json.dumps({"tag_name": state["latest"]}))
    elif "--paginate" in args:
        print(json.dumps(state["pages"]))
    elif any(a.endswith("/releases/generate-notes") for a in args):
        if state.get("fail_notes"):
            sys.exit(1)
        print(json.dumps({"body": "## SemVer Patch\\nGenerated notes\\n"}))
    else:
        sys.exit("Unexpected API call")
elif args[:2] == ["release", "create"]:
    if state.get("fail_publish"):
        state["fail_publish"] = False
        path.write_text(json.dumps(state))
        sys.exit(1)
    assert "--verify-tag" in args
    state["latest"] = args[2]
    state["notes"] = pathlib.Path(args[args.index("--notes-file") + 1]).read_text()
    path.write_text(json.dumps(state))
else:
    sys.exit("Unexpected gh command")
'''


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "repo"
        self.remote = self.base / "remote.git"
        self.repo.mkdir()
        self.git("init", "--initial-branch=main")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "tag.gpgsign", "false")
        (self.repo / ".github/scripts").mkdir(parents=True)
        for name in ("create-release.sh", "validate.py"):
            shutil.copy(ROOT / ".github/scripts" / name, self.repo / ".github/scripts" / name)
        skill = self.repo / "skills/example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("---\nname: example\ndescription: Example. Use when testing.\n---\nExample.\n")
        for name in MANIFESTS:
            path = self.repo / name
            path.parent.mkdir()
            path.write_text(json.dumps({"name": "example", "version": "0.3.0"}, indent=2) + "\n")
        self.git("add", ".")
        self.git("commit", "-m", "Initial release")
        self.git("tag", "-a", "0.3.0", "-m", "Version 0.3.0")
        self.git("init", "--bare", str(self.remote))
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "origin", "main", "--tags")
        self.initial = self.git("rev-parse", "HEAD")
        self.state = self.base / "github.json"
        self.write_state(latest="0.3.0", pages=[[]])
        bin_dir = self.base / "bin"
        bin_dir.mkdir()
        gh = bin_dir / "gh"
        gh.write_text(FAKE_GH)
        gh.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
                        FAKE_GH_STATE=str(self.state), GITHUB_REPOSITORY="example/skills",
                        GITHUB_REF="refs/heads/main", GH_TOKEN="test-token", PYTHONDONTWRITEBYTECODE="1")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True, stderr=subprocess.PIPE).strip()

    def write_state(self, **changes):
        state = json.loads(self.state.read_text()) if self.state.exists() else {}
        state.update(changes)
        self.state.write_text(json.dumps(state))

    def merged_pr(self, labels, number=1):
        self.git("switch", "-c", f"pr-{number}")
        (self.repo / f"change-{number}.txt").write_text(f"Change {number}\n")
        self.git("add", ".")
        self.git("commit", "-m", f"Change {number}")
        self.git("switch", "main")
        self.git("merge", "--no-ff", f"pr-{number}", "-m", f"Merge PR #{number}")
        self.git("push", "origin", "main")
        return {"number": number, "merged_at": "2020-01-01T00:00:00Z",
                "merge_commit_sha": self.git("rev-parse", "HEAD"),
                "labels": [{"name": label} for label in labels]}

    def run_release(self, *args, success=True):
        result = subprocess.run(["bash", ".github/scripts/create-release.sh", *args], cwd=self.repo,
                                env=self.env, capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def remote_refs(self):
        return self.git("ls-remote", "origin")

    def assert_version(self, version):
        remote_head = self.git("ls-remote", "origin", "refs/heads/main").split()[0]
        self.assertEqual(self.git("rev-parse", f"{version}^{{}}"), remote_head)
        for path in MANIFESTS:
            self.assertEqual(json.loads(self.git("show", f"{version}:{path}"))["version"], version)
        state = json.loads(self.state.read_text())
        self.assertEqual(state["latest"], version)
        self.assertIn("Generated notes", state["notes"])

    def test_patch_updates_both_manifests_and_publishes_tagged_commit(self):
        pr = self.merged_pr(["🔨 semver/patch"])
        self.write_state(pages=[[pr]])
        self.run_release()
        self.assert_version("0.3.1")
        self.assertEqual(self.git("log", "-1", "--format=%s"), "Version 0.3.1")
        fields = json.loads(self.state.read_text())["calls"][2]
        self.assertIn("configuration_file_path=.github/release.yml", fields)
        self.assertIn("previous_tag_name=0.3.0", fields)
        refs = self.remote_refs()
        self.run_release()
        self.assertEqual(self.remote_refs(), refs)

    def test_minor_wins_across_pages_and_already_released_pr_is_ignored(self):
        patch = self.merged_pr(["🔨 semver/patch"], 1)
        minor = self.merged_pr(["🆕 semver/minor"], 2)
        old = {**minor, "merge_commit_sha": self.initial, "labels": [{"name": "⚠️ semver/major"}]}
        self.write_state(pages=[[old, patch], [minor]])
        self.run_release()
        self.assert_version("0.4.0")

    def test_none_missing_labels_and_unmerged_pr_do_not_release(self):
        none = self.merged_pr(["semver/none"], 1)
        unlabeled = self.merged_pr([], 2)
        unmerged = {**none, "merged_at": None, "labels": [{"name": "🆕 semver/minor"}]}
        self.write_state(pages=[[none, unlabeled, unmerged]])
        refs = self.remote_refs()
        self.assertIn("No merged PRs", self.run_release())
        self.assertEqual(self.remote_refs(), refs)

    def test_major_aborts_without_changes(self):
        pr = self.merged_pr(["⚠️ semver/major", "🔨 semver/patch"])
        self.write_state(pages=[[pr]])
        refs = self.remote_refs()
        self.assertIn("manually", self.run_release(success=False))
        self.assertEqual(self.remote_refs(), refs)
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_dry_run_does_not_modify_or_publish(self):
        pr = self.merged_pr(["🔨 semver/patch"])
        self.write_state(pages=[[pr]])
        refs = self.remote_refs()
        self.assertIn("0.3.1", self.run_release("--dry-run"))
        self.assertEqual(self.remote_refs(), refs)
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertEqual(len(json.loads(self.state.read_text())["calls"]), 2)

    def test_publication_retry_reuses_tag_without_another_bump(self):
        pr = self.merged_pr(["🔨 semver/patch"])
        self.write_state(pages=[[pr]], fail_publish=True)
        self.run_release(success=False)
        head = self.git("rev-parse", "HEAD")
        refs = self.remote_refs()
        self.run_release()
        self.assert_version("0.3.1")
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertEqual(self.remote_refs(), refs)

    def test_notes_failure_leaves_local_and_remote_refs_untouched(self):
        pr = self.merged_pr(["🔨 semver/patch"])
        self.write_state(pages=[[pr]], fail_notes=True)
        refs = self.remote_refs()
        head = self.git("rev-parse", "HEAD")
        self.run_release(success=False)
        self.assertEqual(self.remote_refs(), refs)
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_mismatched_manifests_abort(self):
        pr = self.merged_pr(["🔨 semver/patch"])
        path = self.repo / MANIFESTS[1]
        path.write_text(json.dumps({"name": "example", "version": "0.4.0"}) + "\n")
        self.git("add", ".")
        self.git("commit", "-m", "Incorrect version")
        self.git("push", "origin", "main")
        self.write_state(pages=[[pr]])
        refs = self.remote_refs()
        self.assertIn("Both manifests", self.run_release(success=False))
        self.assertEqual(self.remote_refs(), refs)
        validation = subprocess.run([sys.executable, ".github/scripts/validate.py"], cwd=self.repo, capture_output=True)
        self.assertEqual(validation.returncode, 1)

    def test_existing_tag_is_never_moved(self):
        pr = self.merged_pr(["🔨 semver/patch"])
        self.write_state(pages=[[pr]])
        self.git("tag", "0.3.1", self.initial)
        self.git("push", "origin", "refs/tags/0.3.1")
        refs = self.remote_refs()
        self.assertIn("will not be moved", self.run_release(success=False))
        self.assertEqual(self.remote_refs(), refs)

    def test_stale_main_and_wrong_branch_abort(self):
        pr = self.merged_pr(["🔨 semver/patch"])
        self.write_state(pages=[[pr]])
        self.git("push", "origin", f"{self.initial}:refs/heads/main", "--force")
        refs = self.remote_refs()
        self.assertIn("origin/main has changed", self.run_release(success=False))
        self.assertEqual(self.remote_refs(), refs)
        self.git("switch", "pr-1")
        self.assertIn("must run on main", self.run_release(success=False))

    def test_rejected_version_commit_does_not_push_tag(self):
        pr = self.merged_pr(["🔨 semver/patch"])
        self.write_state(pages=[[pr]])
        hook = self.remote / "hooks/update"
        hook.write_text('#!/bin/sh\n[ "$1" != "refs/heads/main" ]\n')
        hook.chmod(0o755)
        refs = self.remote_refs()
        self.run_release(success=False)
        self.assertEqual(self.remote_refs(), refs)
        self.assertEqual(json.loads(self.state.read_text())["latest"], "0.3.0")


if __name__ == "__main__":
    unittest.main()
