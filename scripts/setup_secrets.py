#!/usr/bin/env python3
"""
Script that encrypts and makes the repository safe.
"""

from pathlib import Path
from settings import *
import getpass
import os
import subprocess
import sys
import tempfile
import yaml
import string
import random

# TODO: Use real username for ssh-key name

# Secret definitions with metadata
SECRETS_SCHEMA = {
    "ansible_sudo_pass": ("SUDO (Linux root) password", True),
    "ssh_key_passphrase": ("SSH private key passphrase", True),
    "gpg_key_passphrase": ("Passpharse for the main GPG key", True),
    "sonatype_user": ("Sonatype user", False),
    "sonatype_password": ("Sonatype password", True),
}

def ask_user_password(secret_name: str, is_password: bool = True) -> str:
    """
    Ask user for a secret value with confirmation for passwords.
    """
    while True:
        if is_password:
            secret_1 = getpass.getpass(f"Enter your {secret_name}: ")
            secret_2 = getpass.getpass(f"Enter again your {secret_name}: ")
        else:
            secret_1 = input(f"Enter your {secret_name}: ")
            secret_2 = secret_1 # No confirmation for non-passwords

        if not secret_1:
            print("You must enter a non-empty secret. Please try again.")
            continue

        if is_password and secret_1 != secret_2:
            print(f"The {secret_name} values don't match. Please try again.")
            continue

        return secret_1

def is_vault_encrypted(file_path: Path) -> bool:
    """
    Check if a file is encrypted with ansible-vault.
    """
    if not file_path.exists():
        return False
    content = file_path.read_text()
    return content.startswith("$ANSIBLE_VAULT;")

def load_existing_secrets(secrets_path: Path, vault_password_file: Path) -> dict:
    """
    Load existing secrets from file, decrypting if necessary.
    """
    if not secrets_path.exists():
        return {}

    content = secrets_path.read_text()
    if content.startswith("$ANSIBLE_VAULT;"):
        # Decrypt using ansible-vault view
        env = os.environ.copy()
        env["ANSIBLE_VAULT_PASSWORD_FILE"] = str(vault_password_file)

        result = subprocess.run(
            ["ansible-vault", "view", str(secrets_path)],
            capture_output=True,
            text=True,
            env=env
        )

        if result.returncode != 0:
            print(f"\033[31mError decrypting secrets file: {result.stderr}\033[0m")
            sys.exit(1)

        content = result.stdout

    return yaml.safe_load(content) or {}

def create_secure_temp_file(content: str) -> Path:
    """
    Create a temporary file with secure permissions (0600).
    """
    fd, path = tempfile.mkstemp(prefix="ansible_secrets_")
    os.chmod(path, 0o600)
    with os.fdopen(fd, 'w') as f:
        f.write(content)
    return Path(path)

def yaml_escape_value(value: str) -> str:
    """
    Properly escape a value for YAML using PyYAML's serialization.
    This handles all special characters including quotes, newlines, and unicode.
    """
    # Use yaml.dump to get proper escaping, then strip the trailing newline and key
    # yaml.dump with default_style ensures proper quoting when needed
    dumped = yaml.dump({"_": value}, default_flow_style=False, allow_unicode=True)
    # Extract just the value part (after the ': ')
    escaped_value = dumped.split(": ", 1)[1].rstrip('\n')
    return escaped_value

def write_secrets_yaml(secrets_dict: dict, output_path: Path) -> None:
    """
    Write secrets to a YAML file with secure permissions.
    """

    # Make file writable if it exists and is read-only
    if output_path.exists():
        current_mode = output_path.stat().st_mode
        if not (current_mode & 0o200): # Check if user-write bit is not set
            output_path.chmod(current_mode | 0o200) # Add write permission

    # Build the YAML content with comments
    content_parts = ["---"]

    # Group secrets with comments
    groups = {
        "System SUDO and SSH": [
            "ansible_sudo_pass", "ssh_key_passphrase"
        ],
        "SBT Publishing": [
            "gpg_key_passphrase", "sonatype_user", "sonatype_password"
        ]
    }

    for group_name, keys in groups.items():
        content_parts.append(f"\n# {group_name}")
        for key in keys:
            if key in secrets_dict:
                # Use PyYAML's proper escaping for all special characters
                escaped_value = yaml_escape_value(secrets_dict[key])
                content_parts.append(f"{key}: {escaped_value}")

    content_parts.append("") # Final newline

    # Write with secure permissions
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.touch(mode=0o600)
    output_path.write_text("\n".join(content_parts))

def collect_secrets(existing_secrets: dict) -> tuple[dict, bool]:
    """
    Collect all secrets from user, checking for existing values.
    """
    secrets_dict = existing_secrets.copy()
    has_changes = False

    # Auto-set audience values from hardcoded constants (not user-configurable)
    print("\n" + "=" * 60)
    print("Setting up repository secrets")
    print("=" * 60)

    for key, (description, is_password) in SECRETS_SCHEMA.items():
        if key in secrets_dict and secrets_dict[key]:
            # If exists, ask if user wants to override
            display_value = "********" if is_password else secrets_dict[key][:20] + "..."
            if len(secrets_dict[key]) <= 20 or is_password:
                 display_value = "********" if is_password else secrets_dict[key]

            override = input(f"Override existing {key} ({display_value})? [y/N]: ").strip().lower()
            if override != 'y':
                print(f"= Keeping existing value")
                continue

        # Collect new value
        secrets_dict[key] = ask_user_password(description, is_password)
        has_changes = True

    return secrets_dict, has_changes

def generate_vault_password(vault_path: Path) -> None:
    """
    Generate a random vault password file if it doesn't exist.
    """
    if vault_path.exists():
        print(f"\nvault password file already exists: {vault_path}")
        return

    print(f"\nCreating vault.txt file with random password")
    # Generate 32 randomized alphanumeric characters
    chars = string.ascii_letters + string.digits
    password = "".join(random.choice(chars) for _ in range(32))

    vault_path.touch(mode=0o600)
    vault_path.write_text(password)

def encrypt_with_vault(file_path: Path, vault_password_file: Path) -> None:
    """
    Encrypt a file with ansible-vault if not already encrypted.
    """
    if is_vault_encrypted(file_path):
        print(f"= Already encrypted: {file_path}")
        return

    env = os.environ.copy()
    env["ANSIBLE_VAULT_PASSWORD_FILE"] = str(vault_password_file)

    subprocess.run([
        "ansible-vault", "encrypt", str(file_path)
    ], env=env, check=True)

def secure_permissions(file_path: Path, mode: int = 0o400) -> None:
    """
    Set secure permissions on a file.
    """
    file_path.chmod(mode)

def main() -> int:
    """
    Main entry point.
    """
    # Set repository root and change to it
    repo_root = get_repository_root()
    original_dir = Path.cwd()
    os.chdir(repo_root)

    config = load_settings(os.path.join(repo_root, "scripts", "settings.conf"))

    try:
        vault_file = Path(config.VAULT_FILE)
        secrets_file = Path(config.LNX_SECRETS_YML)
        ssh_keys_dir = repo_root / config.SSH_KEY_PATH

        # Set environment variable for ansible-vault
        os.environ["ANSIBLE_VAULT_PASSWORD_FILE"] = str(vault_file)

        print("\nCreation and setup of the repository secrets")

        # Step 1: Create vault password file if needed
        generate_vault_password(vault_file)

        # Step 2: Load existing secrets (handles encrypted files)
        existing_secrets = load_existing_secrets(secrets_file, vault_file)

        # Step 3: Collect all secrets from user
        all_secrets, has_changes = collect_secrets(existing_secrets)

        if has_changes:
            # Step 4: Write secrets file (only if there are changes)
            write_secrets_yaml(all_secrets, secrets_file)

            # Step 6: Encrypt secrets (only if there are changes or file is not)
            if has_changes or not is_vault_encrypted(secrets_file):
                print("\nEncrypting secrets.yml file...")
                encrypt_with_vault(secrets_file, vault_file)
        else:
            print("\nNo changes to secrets - skipping write")
            # Still ensure it's encrypted if it exists
            if secrets_file.exists() and not is_vault_encrypted(secrets_file):
                encrypt_with_vault(secrets_file, vault_file)

        # Step 7: Encrypt SSH private keys
        print("\nEncrypting SSH private keys...")
        if ssh_keys_dir.exists():
            for key_file in ssh_keys_dir.iterdir():
                if str(key_file).endswith(".gitkeep"):
                    continue
                # Skip files with extensions (e.g., .pub)
                if not key_file.suffix and key_file.is_file():
                    encrypt_with_vault(key_file, vault_file)

        # Step 8: Securing permissions...
        print("\nSecuring permissions...")
        if secrets_file.exists():
            secure_permissions(secrets_file, 0o400)

        if vault_file.exists():
            secure_permissions(vault_file, 0o400)

        if ssh_keys_dir.exists():
            for key_file in ssh_keys_dir.iterdir():
                if str(key_file).endswith(".gitkeep"):
                    continue
                if not key_file.suffix:
                    secure_permissions(key_file, 0o400)
                else:
                    secure_permissions(key_file, 0o644)

        print("\n" + "=" * 60)
        print("Secrets setup completed successfully!")
        print("=" * 60)

    finally:
        os.chdir(original_dir)

    return 0

if __name__ == "__main__":
    sys.exit(main())
