#!/usr/bin/env python3
"""
Configuration settings for Ansible WSL scripts.
Python equivalent of settings.sh
"""

import subprocess
import sys
from pathlib import Path

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

# Configuration
ANSIBLE_VERSION = "10.7.0"
ANSIBLE_REPO_PATH = Path("/tmp/ansible-wsl")

# Paths (relative to repository root)
VAULT_FILE = "vault.txt"
LNX_SECRETS_YML = "host_vars/linux/secrets.yml"
WIN_SECRETS_YML = "host_vars/windows/secrets.yml"
SSH_KEY_PATH = "data/ssh_keys"
GPG_KEY_PATH = "data/gpg_keys"
SSL_CERTS_PATH = "data/ssl_certs"
