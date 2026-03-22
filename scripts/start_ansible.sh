#!/bin/bash
#
# Wrapper to start an Ansible playbook from PowerShell
#

# Load configuration
scripts_dir="$(readlink -e "$(dirname ${BASH_SOURCE[0]})")"
source "${scripts_dir}/settings.sh"
pushd "${repository_root}" > /dev/null


playbook="$1"; shift

if [[ -z "${playbook}" || ! -f "${playbook}" ]] ; then
    echo "The playbook '${playbook}' must exist"
    exit 1
fi

cd "${ansible_repo_path}"
ansible-playbook -i inventory "${playbook}" "$@"
result="$?"


popd > /dev/null
exit $result
