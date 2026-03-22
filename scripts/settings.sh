#!/bin/bash

repository_root="$(git rev-parse --show-toplevel 2> /dev/null || readlink -e .)"
if [[ $? > 0 ]] ; then
    echo -e "\e[91mError while running GIT. Exiting.\e[0m"
    exit 1
fi

ansible_core_version="2.17.14"
ansible_version="10.7.0"

ansible_repo_path=/tmp/ansible-wsl
vault_file=vault.txt
lnx_secrets_yml=host_vars/linux/secrets.yml
win_secrets_yml=host_vars/windows/secrets.yml
