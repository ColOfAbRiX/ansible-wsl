#!/bin/bash
#
# Script that encrypts and makes the secrets of the repository safe
#

ask_user_password() {
    local __resultvar="$1"
    local secret_name="$2"

    local secret_1=""
    local secret_2="not_set_yet"
    while [[ "${secret_1}" != "${secret_2}" || -z "${secret_1}" ]] ; do
        echo -en "\nEnter your ${secret_name}: "       && read -s secret_1
        echo -en "\nEnter again your ${secret_name}: " && read -s secret_2
        if [[ -z "${secret_1}" || -z "${secret_2}" ]] ; then
            echo -e "You must endter a non-empty secret. Please enter them again."
        fi
        if [[ "${secret_1}" != "${secret_2}" ]] ; then
            echo -e "The two ${secret_name} don't match. Please enter them again."
        fi
    done

    echo ""
    eval $__resultvar="'${secret_1}'"
}

general_secrets() {
    local secrets_file="$1"

    echo -e "\nSetting general secrets (passwords, keys, passphrases, ...)"
    ask_user_password sudo_pwd "SUDO (Linux root) password"
    ask_user_password ssh_key_pwd "SSH private key passphrase"
    ask_user_password nexus_pwd "Nexus/Maven password"

    touch "${secrets_file}"
    chmod 0600 "${secrets_file}"
    cat > "${secrets_file}" <<EOF
---
# System SUDO
ansible_sudo_pass: '${sudo_pwd}'

# SSH Key passpgrase
ssh_key_passphrase: '${ssh_key_pwd}'

EOF
}

# Load configuration
scripts_dir="$(readlink -e "$(dirname ${BASH_SOURCE[0]})")"
source "${scripts_dir}/settings.sh"
export ANSIBLE_VAULT_PASSWORD_FILE="${vault_file}"
pushd "${repository_root}" > /dev/null


echo -e "\nCreation and setup of the repository secrets"

# Create vault.txt file
if [[ ! -f "${vault_file}" ]] ; then
    echo -e "\nCreating vault.txt file with random password"
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 > "${vault_file}"
fi


# Create linux/secrets.yml file
if [[ ! -f "${lnx_secrets_yml}" ]] ; then
    general_secrets /tmp/general_secrets
    cat /tmp/general_secrets > "${lnx_secrets_yml}"
    rm /tmp/general_secrets
else
    echo "You already have a ${lnx_secrets_yml}, no need to ask for passwords again"
fi

# Create SSH keypair
if [[ ! -f "ssh_keys/users/$(whoami)" ]] ; then
    echo "Creating new SSH keypair"
    ssh-keygen -o \
        -a 100 \
        -t ed25519 \
        -N "${ssh_key_pwd}" \
        -f "ssh_keys/users/$(whoami)" \
        -C "SSH key for $(whoami) created on $(date +"%d/%m/%Y")"
fi
# Encrypt secrets.yml file
echo -e "\nEncrypt secrets.yml files..."
ansible-vault encrypt "${lnx_secrets_yml}"

# Secure permissions of secrets
echo -e "\nSecuring permissions"
ls -1 ssh_keys/users/* | egrep -v '\.\w+$' | xargs -I {} ansible-vault encrypt {}
ls -1 ssh_keys/users/* | egrep -v '\.\w+$' | xargs -I {} chmod 0440 {}
chmod 0440 "${lnx_secrets_yml}"
chmod 0440 "${vault_file}"
chmod 0440 ssh_keys/users/*


popd > /dev/null
exit 0
