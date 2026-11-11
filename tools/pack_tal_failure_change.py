#!/usr/bin/env python3
"""Package the complete reviewable source and its exact file checksums."""

import hashlib
import json
from pathlib import Path
import subprocess
import zipfile


def main():
    root = Path(__file__).resolve().parents[1]
    name = "quote_app_tal_failure_change_v1_1"
    destination = root / "build" / "tal_failure_change" / f"{name}.zip"
    destination.parent.mkdir(parents=True, exist_ok=True)

    def git(*args):
        return subprocess.check_output(["git", *args], cwd=root).decode().strip()

    paths = git("ls-files", "-z", "--cached", "--others", "--exclude-standard").split("\0")
    checksums = {}
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for relative in sorted(set(paths)):
            if not relative:
                continue
            source = root / relative
            # Signing material is unnecessary for a source review, even when
            # it was tracked in the upstream repository.
            if (not source.is_file() or source.is_symlink()
                    or relative.startswith(("build/", ".git/", ".dart_tool/"))
                    or source.name == "key.properties"
                    or source.suffix in (".jks", ".keystore")
                    or source.name.startswith(".env") and source.name != ".env.example"):
                continue
            checksums[relative] = hashlib.sha256(source.read_bytes()).hexdigest()
            archive.write(source, f"{name}/{relative}")
        archive.writestr(f"{name}/TAL_DELIVERY.json", json.dumps({
            "requirements": "tal_failure_change_plugin_v1_1.zip",
            "base_branch": "fix/schopenhauer-concept-graphs",
            "base_commit": "efe30bb21bb60098f25f5e1415d7045c03beec1e",
            "working_branch": git("branch", "--show-current"),
            "source_commit": git("rev-parse", "HEAD"),
            "working_tree_dirty": bool(git("status", "--porcelain")),
            "source_sha256": checksums,
            "scope": "Tal V1.1 local workflow in existing FP ledger and PRP host",
        }, ensure_ascii=False, indent=2))
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix(".zip.sha256").write_text(f"{digest}  {destination.name}\n")
    print(f"{destination} ({destination.stat().st_size} bytes)\nSHA256 {digest}")


if __name__ == "__main__":
    main()
