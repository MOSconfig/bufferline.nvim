#!/usr/bin/env python3
"""Assemble doc/bufferline.txt from the authored sources in wiki/help/.

The wiki is the only authored documentation source. The Vim help file is a
generated artifact that stays committed to Git so `:help bufferline.nvim`
works for users who install the plugin without the wiki.

Usage:
    python3 scripts/gen_help.py            # write doc/bufferline.txt
    python3 scripts/gen_help.py --check    # fail if it is out of sync
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "wiki" / "help"
TARGET = ROOT / "doc" / "bufferline.txt"


def source_files() -> list[Path]:
    """Return the help fragments in their deterministic numeric order."""
    files = sorted(SOURCE_DIR.glob("*.txt"), key=lambda p: p.name)
    if not files:
        raise SystemExit(f"no help sources found in {SOURCE_DIR}")
    return files


def render() -> str:
    """Concatenate fragments into the final help document."""
    parts = [path.read_text(encoding="utf-8") for path in source_files()]
    # Fragments are stored without a trailing separator; a single newline
    # rejoins them exactly as the sections appear in the help file.
    return "\n".join(parts)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed help file matches the sources",
    )
    args = parser.parse_args(argv)

    rendered = render()

    if args.check:
        if not TARGET.exists():
            print(f"missing generated file: {TARGET}", file=sys.stderr)
            return 1
        current = TARGET.read_text(encoding="utf-8")
        if current != rendered:
            print(
                "doc/bufferline.txt is out of sync with wiki/help/.\n"
                "Run: python3 scripts/gen_help.py",
                file=sys.stderr,
            )
            return 1
        print("doc/bufferline.txt is up to date")
        return 0

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(rendered, encoding="utf-8")
    print(f"wrote {TARGET.relative_to(ROOT)} from {len(source_files())} sources")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
