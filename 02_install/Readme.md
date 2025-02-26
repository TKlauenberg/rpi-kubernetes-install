# Installation steps
- use 001-prepare-ssh-key.sh to get the public keys of the nodes
- execute ansible-playbook rpi.yaml --become --become-user root (for ubuntu)
- get certificate signing request with kubctl get csr
- approve csr with kubectl certificate approve <csr-name>