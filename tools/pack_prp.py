#!/usr/bin/env python3
"""Build the versioned PRP source delivery, excluding local/ignored files."""

import hashlib
import json
from pathlib import Path
import subprocess
import zipfile


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    version = "v1.0.1"
    package = f"quote_app_prp_{version}"
    destination = root / "build" / "prp" / f"{package}.zip"
    destination.parent.mkdir(parents=True, exist_ok=True)
    paths = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=root,
    ).decode().split("\0")
    # Pinned development base, also available in shallow CI checkouts.
    base = "d83386c20f8243cd0e35f5c582de03e5a1595a8c"
    checksums = {}
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for relative in sorted(set(paths)):
            if not relative:
                continue
            source = root / relative
            if not source.is_file() or source.is_symlink():
                continue
            if relative.startswith(("build/", ".git/", ".dart_tool/")):
                continue
            archive.write(source, f"{package}/{relative}")
            if relative.startswith(("lib/prp_plugin/", "lib/prp_plugin_host/", "test/prp_plugin/")):
                checksums[relative] = hashlib.sha256(source.read_bytes()).hexdigest()
        archive.writestr(f"{package}/PRP_DELIVERY.json", json.dumps({
            "version": version,
            "base_branch": "fix/schopenhauer-audit-economy-20261103",
            "base_commit": base,
            "plugin_sha256": checksums,
            "scope": "I0-I5; optional forecast and I6 excluded",
        }, ensure_ascii=False, indent=2))
    print(f"Source package: {destination} ({destination.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
