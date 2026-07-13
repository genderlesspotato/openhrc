#!/bin/sh

RELEASE=$(sysctl kern.version | grep -q current && echo snapshots || echo $(uname -r))
ARCH=$(uname -p)
export PKG_PATH=https://cdn.openbsd.org/pub/OpenBSD/$RELEASE/packages/$ARCH/

echo "Using $PKG_PATH"
pkg_add -z ansible git py3-netaddr

if [[ -d ".git" ]]
then
    echo "Updating OHRC..."
    git pull
else
    echo "Downloading OHRC..."
    git clone https://github.com/ioc32/openhrc
    cd openhrc
fi

mkdir -p inventory/group_vars/router
[ -f inventory/group_vars/router/vars.yml ] || cp inventory/group_vars/router/vars.yml.example inventory/group_vars/router/vars.yml
[ -f inventory/group_vars/router/vault.yml ] || cp inventory/group_vars/router/vault.yml.example inventory/group_vars/router/vault.yml

ansible-galaxy collection install -r requirements.yml

echo "Bootstrap done, set variables in inventory/group_vars/router/vars.yml,"
echo "encrypt secrets in inventory/group_vars/router/vault.yml with"
echo "'ansible-vault encrypt inventory/group_vars/router/vault.yml', then run configure.sh"
