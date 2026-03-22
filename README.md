# Ansible WSL2 Configuration

Ansible playbook to configure WSL2 (Ubuntu 22.04+) with repeatable, multi-distro support.

## Supported Distributions

- Ubuntu 22.04+
- Debian (future)
- Other Debian-based distributions

## Project Structure

```
ansible-wsl-2/
├── ansible.cfg          # Ansible configuration
├── hosts                # Inventory file
├── playbook.yml         # Main playbook
├── group_vars/          # Group variables
│   └── all.yml
├── roles/               # Ansible roles (add your own)
├── scripts/
│   └── setup.sh        # Bootstrap script
├── requirements.yml     # Galaxy collections
└── .gitignore          # Git ignore rules
```

## Quick Start

### 1. Run the bootstrap script

```bash
bash scripts/setup.sh
```

### 2. Execute the playbook

```bash
ansible-playbook -i hosts playbook.yml
```

## Configuration

### Inventory

Edit the `hosts` file to configure your WSL installations:

- `localhost` - Current WSL instance
- Add more hosts for multiple WSL installations

### Variables

Edit `group_vars/all.yml` to customize:
- Common packages to install
- Timezone
- Shell configuration
- WSL integration settings

### Distribution-Specific Variables

Create `group_vars/ubuntu.yml` or `group_vars/debian.yml` for distribution-specific settings.

## Adding New Roles

1. Create a new role:
   ```bash
   ansible-galaxy role init roles/your_role_name
   ```

2. Add the role to `playbook.yml`:
   ```yaml
   - name: Your Role
     import_role:
       name: your_role_name
   ```

## Security

- **Never commit** `vault.txt`, `secrets.yml`, or private keys
- Use Ansible Vault for sensitive data: `ansible-vault encrypt secrets.yml`
- The `.gitignore` file excludes common sensitive files

## Requirements

- Python 3.8+
- Ansible 2.14+
- Ubuntu 22.04+ or Debian-based distro in WSL2

## License

MIT
