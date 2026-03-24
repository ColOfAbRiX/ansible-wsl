#!/bin/bash

repository_root="$(git rev-parse --show-toplevel 2> /dev/null || readlink -e .)"
if [[ $? > 0 ]] ; then
    echo -e "\e[91mError while running GIT. Exiting.\e[0m"
    exit 1
fi

source "$repository_root/scripts/settings.conf"
