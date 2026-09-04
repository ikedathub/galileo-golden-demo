#!/usr/bin/env python3
"""Build a domain's pgvector index unless it already exists.

Keeps Codespace restarts cheap: the index survives in the database, so this
only does real work on a fresh database.
"""
import os
import subprocess
import sys

sys.path.insert(0, os.getcwd())

from setup_env import setup_environment  # noqa: E402


def main() -> int:
    domain = sys.argv[1] if len(sys.argv) > 1 else "bank"
    setup_environment()

    if not os.environ.get("OPENAI_API_KEY"):
        print("ℹ️  OPENAI_API_KEY not set — skipping index build")
        return 0

    try:
        from helpers.pgvector_utils import collection_exists

        if collection_exists(domain, "hosted"):
            print(f"✓ index for '{domain}' already present")
            return 0
    except Exception as exc:
        print(f"ℹ️  could not check for an existing index ({exc}); building it")

    print(f"→ building index for '{domain}'...")
    return subprocess.call([sys.executable, "helpers/setup_vectordb.py", domain])


if __name__ == "__main__":
    sys.exit(main())
