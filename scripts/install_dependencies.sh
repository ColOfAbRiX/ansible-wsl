#!/bin/bash
#
# Install dependencies
#

is_ansible_installed() {
    ansible --version > /dev/null 2>&1
}

is_ansible_version() {
    local version="$1"
    ansible --version | egrep -q "${version}"
}

# Load configuration
scripts_dir="$(readlink -e "$(dirname ${BASH_SOURCE[0]})")"
source "${scripts_dir}/settings.sh"
pushd "${repository_root}" > /dev/null


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root: sudo $0"
   exit 1
fi

# Install prerequisites
apt install -y python3 python3-pip python3-venv python3-packaging dos2unix

# Removing existing previous installations of this repo
rm -rf "${ansible_repo_path}"

if ! is_ansible_installed || ! is_ansible_version "${ansible_core_version}" ; then
    # Remove previous Ansible installations
    apt remove ansible -y > /dev/null 2>&1
    python3 -m pip uninstall -y ansible ansible-core > /dev/null 2>&1

    # Install ansible-core using pip (following official documentation)
    python3 -m pip install "ansible-core==${ansible_core_version}"

    # Install the full ansible package which includes ansible-core and collections
    python3 -m pip install "ansible==${ansible_version}"
fi

# Double check that Ansible works
if ! is_ansible_installed ; then
    echo "Issues with Ansible installation"
    exit 1
fi

# Double check the version, or it will fail later
if ! is_ansible_version "${ansible_core_version}" ; then
    echo "Ansible ${ansible_core_version} is needed but another version is installed on your system"
    exit 1
fi

popd > /dev/null

exit 0
