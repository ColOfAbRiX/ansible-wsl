# WSL Development Environment

This project allows you to automatically configure a WSL development environment with repeatable, customizable settings.

Some of the benefits of this project are:

* Configure your Windows laptop with SSH keys, GPG keys, and development tools
* Edit your code in Windows and build/run applications inside WSL
* Run Docker, etcd, and any other Linux application
* Share the Windows home directory and the Linux home directory
* Use bash or any other shell of your liking
* Have plenty of modern command line tools pre-configured

## Prerequisites

Before running the setup, make sure you have:

1. **WSL installed** with an Ubuntu 22.04+ distribution
2. **Your WSL user created** - you'll set the username in the Configuration section
3. **Your Windows username** - you'll set this in the Configuration section

## First Execution

### Start WSL

If you never opened your freshly installed WSL installation:

* Open the terminal of the WSL installation, you'll be asked to setup the main user.
* Input a username. It's recommended to use your Windows username in lowercase with no spaces (e.g., if your Windows user is `Fabrizio Colonna`, use `fabriziocolonna`), but you can choose any username and configure it later.
* Insert a password that will become your `sudo` password.
* Close the terminal.

### Configuration

Clone this repository in a location accessible from WSL (e.g., under your Windows home directory).

Create the file `<repo_root>/group_vars/all/user.yml` and add the following content to set your first and last name:

```yaml
# Your first name, first letter capital
first_name: '...'
# Your last name, first letter capital
last_name: '...'
```

**Required:** Create the file `<repo_root>/host_vars/linux/user.yml` and add the following content to set your usernames:

```yaml
# Your Windows username
win_user: '...'

# Your Linux username
lnx_user: '...'

# Network name of the computer
wsl_hostname: '...'
```

These variables are required and will be used to build other configuration settings for your environment.

If you want to customize more settings have a look at the [Customizing](#customizing-your-setup) section.

If you have existing SSH or GPG keys read the [SSH & GPG Keys section](#ssh--gpg-keys) below. If you DO NOT have existing keys you can skip that section.

### Run the Setup

Open **PowerShell** inside this repository root directory and run:

```powershell
.\run_all.ps1
```

If you have installed more than one Linux distribution the script will ask you to choose where you want to install it.

## SSH & GPG Keys

### Using Existing Keys

If you **already have SSH or GPG keys** that you wish to keep, you can copy them into this repository instead of having new ones created.

To use your existing keys place them in this repository:

* **SSH keys:**
  * Public key: `<repo_root>/data/ssh_keys/users/<linux_username>.pub`
  * Private key: `<repo_root>/data/ssh_keys/users/<linux_username>`
* **GPG keys:**
  * Public key: `<repo_root>/data/gpg_keys/<linux_username>.pub.asc`
  * Private key(s): `<repo_root>/data/gpg_keys/<linux_username>.sec.asc` and `<linux_username>.ssb.asc`
  * Owner trust: `<repo_root>/data/gpg_keys/<linux_username>.ownertrust.txt`

If you want to know if your files contain OpenSSH keys, you can open them with a text editor. A valid OpenSSH **public key** looks something like:

```
ssh-ed25519 AAAAC3NzaC1 ...... o+78oNbwL A nice description here
```

while a valid OpenSSH **private key** looks something like:

```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABBIMma4dY
....
Pu8SX8PYRw==
-----END OPENSSH PRIVATE KEY-----
```

You can now go back to the standard installation steps.

### Generating New Keys

If you don't have existing keys, the setup script will generate new ones for you during the first execution.

## KeeAgent Integration

KeeAgent is a plugin for KeePass that allows you to use your SSH keys stored in KeePass as an SSH agent. This means you can keep all your passwords and SSH keys in one secure, encrypted database.

### How It Works

* KeePass stores your SSH keys securely in its encrypted database
* KeeAgent acts as an SSH agent, exposing your keys to WSL through a socket
* Your WSL environment connects to this socket to authenticate without needing separate SSH key files in Linux

### Setting Up KeePass and KeeAgent on Windows

1. **Install KeePass:**
   * Download from [keepass.info](https://keepass.info/)
   * Install and create a new database with a strong master password

2. **Install KeeAgent Plugin:**
   * Download KeeAgent from [keepass.info/plugins/contrib/keeagent.html](https://keepass.info/plugins/contrib/keeagent.html)
   * Extract the `.plgx` file to your KeePass `Plugins` folder (usually `C:\Program Files\KeePass Password Safe 2\Plugins`)
   * Restart KeePass

3. **Configure KeeAgent:**
   * Open KeePass, go to Tools → KeeAgent Settings
   * Under "Agent Mode", select "Enable KeeAgent"
   * Under "Socket Type", select "Named pipe (Windows)" or "Unix domain socket (WSL)"
   * For WSL integration, enable "Allow socket to be used from WSL" and note the socket path (default: `/mnt/c/Users/<username>/.ssh/agent.sock`)
   * Click OK

4. **Add Your SSH Keys to KeePass:**
   * Create or open an entry in KeePass
   * Go to the "KeeAgent" tab
   * Check "Add key to agent"
   * Import your SSH private key
   * Set the key's passphrase if prompted

5. **Enable in This Project:**
   * Edit `<repo_root>/host_vars/linux/ssh.yml`
   * Set `wsl_keeagent_enabled: true`
   * Ensure the socket path in `host_vars/linux/keeagent.yml` matches your KeeAgent configuration

## What Gets Configured

| Component            | What it does                                                         |
|----------------------|----------------------------------------------------------------------|
| **WSL Integration**  | Hostname, wsl.conf, .wslconfig, Windows home mapping, daily cleanups |
| **OpenSSH**          | SSH client/server with key management                                |
| **Bash**             | Shell with aliases, autocomplete, history, and MOTD                  |
| **SSH Keys**         | Automatic key deployment and encryption                              |
| **GPG Keys**         | GPG key import and trust configuration                               |
| **SSL Certificates** | Certificate installation                                             |
| **Git**              | System-wide and per-user configuration with aliases                  |
| **Java**             | JDK installation                                                     |
| **Scala**            | Scala, SBT, and Ammonite                                             |
| **Docker**           | Docker Engine setup                                                  |

## Running Specific Components

After initial setup, you can reconfigure individual parts using tags:

```bash
./ansible --tags git           # Reconfigure Git
./ansible --tags docker        # Reconfigure Docker
```

See the code inside the `/roles` directory to discover the complete list of tags.

## Customizing Your Setup

This project uses a layered configuration system. Settings at more specific levels override general defaults:

```
   host_vars/linux/      ← Your machine-specific settings (gitignored)
   group_vars/wsl_*      ← Project defaults
   group_vars/all/       ← Your personal identity
```

The general configuration for the project is fully contained inside each Ansible role or inside the directory `<repo_root>/group_vars/wsl_installations`. If you want to customize the existing settings you must only work inside `<repo_root>/host_vars/linux`. The Ansible configuration variables that you put in this directory will override the other settings and the files will not be added to GIT.

**REMEMBER:** Change variables only inside `<repo_root>/host_vars/linux` and nowhere else, or bad things will happen down the line.

To know what settings you can configure you can look at the default values and options in each Ansible role in `<repo_root>/roles/**/defaults/main.yml` (there is also an extensive description inside) and at the variables defined in `<repo_root>/group_vars`.

### Common Customizations

**Change your SSH key type** (edit `host_vars/linux/ssh.yml`):
```yaml
main_user_ssh:
  target_file: "~/.ssh/id_rsa"   # Changed from default ed25519
```

**Change your Git email** (edit `host_vars/linux/git.yml`):
```yaml
main_user_git:
  gitconfig:
    user:
      email: "your@email.com"
```

## Secrets & Git Ignore

This project uses `.gitignore` to protect sensitive files from being accidentally committed to your repository.

### What is Git-Ignored

The following files and directories are excluded from version control:

* **`data/`** - Your SSH keys, GPG keys, and SSL certificates
* **`vault.txt`** - The Ansible Vault encryption key
* **`host_vars/linux/secrets.yml`** - Encrypted passwords and passphrases

### Secrets Management

Sensitive values are encrypted with Ansible Vault for secure storage:

* **Passwords and passphrases** are stored encrypted in `host_vars/linux/secrets.yml`
* **SSH private keys** in `data/ssh_keys/` are also encrypted
* The `vault.txt` file contains the encryption key and must **never** be committed to git

To update your secrets manually:
```bash
./scripts/setup_secrets.py
```

### Why This Matters

The `.gitignore` file ensures that even if you push your configuration to a public repository, your sensitive data remains protected. Only the encrypted files (which are useless without the vault key) and your configuration templates are tracked.

## Requirements

* WSL with Ubuntu 22.04+
* Python 3.8+
* Ansible 2.14+

## License

MIT

## Author Information

Fabrizio Colonna <colofabrix@tin.it>
