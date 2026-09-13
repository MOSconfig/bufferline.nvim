#!/usr/bin/env python3
"""Test the wiki publishing script from .github/workflows/wiki-release.yml.

The script under test is extracted from the workflow itself — between the
`# BEGIN sync-script` and `# END sync-script` markers — so the test cannot drift
away from what CI actually runs. It is executed against local fixture
repositories; no network access and no credentials are involved.

    python3 scripts/test_wiki_sync.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "wiki-release.yml"

failures: list[str] = []
checks = 0


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        failures.append(message)


def extract_sync_script() -> str:
    text = WORKFLOW.read_text(encoding="utf-8")
    match = re.search(
        r"^(\s*)# BEGIN sync-script\n(.*?)^\s*# END sync-script\s*$",
        text,
        re.DOTALL | re.MULTILINE,
    )
    if not match:
        raise SystemExit("could not find the sync script markers in the workflow")
    return textwrap.dedent(match.group(2))


def git(*args: str, cwd: Path, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        env={**os.environ, **(env or {})},
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def make_fixture(tmp: Path) -> tuple[Path, Path]:
    """Create a bare 'wiki' remote with one authored and one manual page."""
    remote = tmp / "wiki-remote.git"
    seed = tmp / "seed"
    subprocess.run(["git", "init", "--quiet", "--bare", str(remote)], check=True)
    subprocess.run(["git", "init", "--quiet", str(seed)], check=True)

    env = {
        "GIT_AUTHOR_NAME": "Fixture",
        "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
        "GIT_COMMITTER_NAME": "Fixture",
        "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
    }
    (seed / "Home.md").write_text("# stale home\n", encoding="utf-8")
    (seed / "Manual-Page.md").write_text("# hand written, not from the repo\n", encoding="utf-8")
    git("add", "-A", cwd=seed, env=env)
    git("commit", "--quiet", "-m", "seed", cwd=seed, env=env)
    git("remote", "add", "origin", str(remote), cwd=seed, env=env)
    git("push", "--quiet", "origin", "HEAD:master", cwd=seed, env=env)
    return remote, seed


def run_sync(script: str, workdir: Path, remote: Path) -> subprocess.CompletedProcess:
    script_path = workdir / "sync.sh"
    script_path.write_text(script, encoding="utf-8")
    env = {
        **os.environ,
        "WIKI_TOKEN": "fixture-token-not-a-real-secret",
        "WIKI_REMOTE": str(remote),
        "WIKI_USER": "fixture-user",
        "SOURCE_REF": "refs/tags/v0.0.0-fixture",
        "GITHUB_OUTPUT": str(workdir / "github_output"),
        "GIT_AUTHOR_NAME": "Fixture",
        "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
    }
    return subprocess.run(
        ["bash", str(script_path)],
        cwd=workdir,
        env=env,
        capture_output=True,
        text=True,
    )


def clone_remote(remote: Path, dest: Path) -> Path:
    subprocess.run(["git", "clone", "--quiet", str(remote), str(dest)], check=True)
    return dest


def main() -> int:
    if shutil.which("git") is None:
        print("git is required for this test", file=sys.stderr)
        return 1

    script = extract_sync_script()
    check("--force" not in script, "sync script must never force-push")
    check("GIT_ASKPASS" in script, "sync script must use an askpass helper")
    check("$WIKI_TOKEN" not in script.split("ASKPASS")[0], "token must not be used before masking")
    check("add-mask" in script, "sync script must mask the token")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        remote, _ = make_fixture(tmp)

        workdir = tmp / "work"
        (workdir / "wiki").mkdir(parents=True)
        (workdir / "wiki" / "Home.md").write_text("# fresh home\n", encoding="utf-8")
        (workdir / "wiki" / "Guide.md").write_text("# a new guide\n", encoding="utf-8")
        # A nested directory must not be published as a page.
        (workdir / "wiki" / "help").mkdir()
        (workdir / "wiki" / "help" / "00-header.txt").write_text("help\n", encoding="utf-8")

        first = run_sync(script, workdir, remote)
        check(first.returncode == 0, f"first sync failed: {first.stderr or first.stdout}")

        published = clone_remote(remote, tmp / "check-1")
        check((published / "Home.md").exists(), "Home.md was not published")
        check(
            (published / "Home.md").read_text(encoding="utf-8") == "# fresh home\n",
            "Home.md was not updated to the authored content",
        )
        check((published / "Guide.md").exists(), "Guide.md was not published")
        check(
            (published / "Manual-Page.md").exists(),
            "an unrelated wiki page was deleted; publishing must preserve manual pages",
        )
        check(
            not (published / "help").exists(),
            "nested wiki/help/ must not be published as wiki pages",
        )

        history = git("rev-list", "--count", "HEAD", cwd=published)
        check(int(history) == 2, f"expected one new commit on top of the seed, got {history}")

        # Second run with unchanged sources must be a no-op.
        second = run_sync(script, workdir, remote)
        check(second.returncode == 0, f"second sync failed: {second.stderr or second.stdout}")
        check(
            "already up to date" in second.stdout,
            f"second sync should be a no-op, got: {second.stdout.strip()!r}",
        )
        again = clone_remote(remote, tmp / "check-2")
        check(
            int(git("rev-list", "--count", "HEAD", cwd=again)) == 2,
            "an unchanged sync created an extra commit",
        )

        # The ::add-mask:: line is the one place the value legitimately appears:
        # it is a workflow command consumed by the Actions runner to register the
        # value for redaction, and is never rendered into the log. Every other
        # line must be free of it.
        combined = first.stdout + first.stderr + second.stdout + second.stderr
        leaked = [
            line
            for line in combined.splitlines()
            if "fixture-token-not-a-real-secret" in line
            and not line.startswith("::add-mask::")
        ]
        check(not leaked, f"the token leaked into the sync script output: {leaked}")

        masked = [line for line in combined.splitlines() if line.startswith("::add-mask::")]
        check(bool(masked), "the sync script never registered the token for masking")

        before = git("rev-parse", "HEAD", cwd=again)
        (workdir / "wiki" / "Leak.md").symlink_to(workdir / "sync.sh")
        rejected = run_sync(script, workdir, remote)
        check(rejected.returncode != 0, "symlinked pages must be rejected")
        check(git("ls-remote", str(remote), "HEAD", cwd=workdir).split()[0] == before,
              "rejected symlink must not modify the remote")
        (workdir / "wiki" / "Leak.md").unlink()
        workflow = WORKFLOW.read_text(encoding="utf-8")
        check("ref: ${{ needs.validate.outputs.sha }}" in workflow,
              "publishing must use the exact validated commit")

        # A missing/uninitialized wiki must fail with actionable guidance.
        missing = run_sync(script, workdir, tmp / "does-not-exist.git")
        check(missing.returncode != 0, "sync must fail when the wiki repository is absent")
        check(
            "Enable the wiki" in missing.stdout + missing.stderr,
            "failure message must explain that the wiki needs initializing",
        )

    if failures:
        print(f"FAILED {len(failures)} of {checks} checks\n", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print(f"ok - {checks} checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
