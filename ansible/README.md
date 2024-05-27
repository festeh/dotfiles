# Ansible things

Inventory: `~/.ansible/hosts/inventory`

# Start from a task
ansible-playbook -i ~/.ansible/hosts/inventory -l <host> --start-at-task="<task>" <playbook>

# Providing variables
ansible-playbook -i ~/.ansible/hosts/inventory -l <host> -e "var1=value1 var2=value2" <playbook>

# Setting a key
ansible-playbook -i ~/.ansible/hosts/inventory -l <host> --key-file=~/.ssh/id_rsa <playbook>

# Packages from ansible-galaxy
* caddy_ansible
* cimon-io.asdf
* isaackehle.ansible_pm2


# Setup asdf
ansible-playbook setup_asdf.yml -i ~/.ansible/hosts -e target=contabo --key-file ~/.ssh/contabo -e ansible_user=root -e ansible_os_family=Debian -e asdf_group=root

# Setup pm2
- Use -e "{'flags' : ['init']}"

# pm2

Use pm2 start SERVER_FILE to run

# Caddy
