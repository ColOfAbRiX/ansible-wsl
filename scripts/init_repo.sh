#!/bin/bash
#
# Initializes the ansible repository to be usable on the target
#

if [[ $EUID -eq 0 ]]; then
   echo "This script must NOT run as root"
   exit 1
fi

# Load configuration
scripts_dir="$(readlink -e "$(dirname ${BASH_SOURCE[0]})")"
source "${scripts_dir}/settings.sh"
pushd "${repository_root}" > /dev/null

# Download Ansible roles and dependencies
ansible-galaxy install -r requirements.yml --ignore-errors 2> /dev/null

# Create target directory and copy this repository
echo -e "\nCreate ansible target directory and copy this repository"
rm -rf "${ANSIBLE_REPO_PATH}" 2> /dev/null
mkdir "${ANSIBLE_REPO_PATH}"
shopt -s extglob
cp -r !(.*) "${ANSIBLE_REPO_PATH}"
shopt -u extglob

pushd "${ANSIBLE_REPO_PATH}" > /dev/null

# Set permissions for this repository
echo -e "\nSet permissions for the repository"
find . -type f -exec chmod 0644 {} \;
find . -type d -exec chmod 0755 {} \;
find scripts/ \( -type f -name '*.sh' -o -name '*.py' \) -exec chmod 0755 {} \;

# Ensure there's no pollution from Windows EOL
echo -e "\nEnforcing proper EOL in Linux"
find . -type f -print0 | xargs -0 -n 1 -P 4 dos2unix > /dev/null 2>&1

popd > /dev/null

echo -e "\nRepository correctly initialized"
exit 0
