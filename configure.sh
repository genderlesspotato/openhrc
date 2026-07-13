#!/bin/sh

echo "Running playbook..."
ansible-playbook -i inventory/hosts.yml site.yml --ask-vault-pass

echo "System configured! It's time to reboot now. Have fun!"
