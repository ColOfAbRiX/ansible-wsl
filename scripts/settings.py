#!/usr/bin/env python3
"""
Configuration settings for Ansible WSL scripts.
Python equivalent of settings.sh
"""
from pathlib import Path
from types import SimpleNamespace
import os
import subprocess
import sys

def get_repository_root() -> Path:
    """Get the git repository root directory."""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            check=True
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError:
        print("\033[91mError while running GIT. Exiting.\033[0m", file=sys.stderr)
        sys.exit(1)

def load_settings(filepath: str) -> SimpleNamespace:
    """Parse a .conf file into a SimpleNamespace object."""
    settings_dict = {}

    if not os.path.exists(filepath):
        print(f"Warning: {filepath} not found.")
        return SimpleNamespace()

    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue

            key, value = line.split('=', 1)

            clean_key = key.strip()
            clean_value = value.strip().strip('"').strip("'")

            settings_dict[clean_key] = clean_value

    return SimpleNamespace(**settings_dict)
