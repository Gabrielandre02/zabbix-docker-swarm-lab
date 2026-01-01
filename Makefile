.PHONY: help deploy destroy stop vagrant-up vagrant-destroy ansible inventory

IPS_VMS ?= 10.0.0.22
INVENTORY = ansible-deploy-full-zabbix/inventory/hosts.ini

help:
	@echo "Targets:"
	@echo "  deploy          - Sobe a VM e executa o Ansible (./deploy.sh)"
	@echo "  destroy         - Remove toda a infra (./destroy.sh)"
	@echo "  stop            - Para a VM do Vagrant (./stop.sh)"
	@echo "  vagrant-up      - Sobe somente a VM (vagrant up)"
	@echo "  vagrant-destroy - Remove somente a VM (vagrant destroy -f)"
	@echo "  ansible         - Executa somente o Ansible playbook"
	@echo "  inventory       - Atualiza ansible_host no inventory (use IPS_VMS=IP)"

deploy:
	@bash ./deploy.sh

destroy:
	@bash ./destroy.sh

stop:
	@bash ./stop.sh

vagrant-up:
	@vagrant up

vagrant-destroy:
	@vagrant destroy -f

ansible:
	@ANSIBLE_CONFIG=ansible-deploy-full-zabbix/ansible.cfg ANSIBLE_ROLES_PATH=ansible-deploy-full-zabbix/roles ansible-playbook -i ansible-deploy-full-zabbix/inventory/hosts.ini ansible-deploy-full-zabbix/playbooks/deploy-full-zabbix.yml

inventory:
	@tmp=$$(mktemp); awk -v ip="$(IPS_VMS)" '{ if ($$0 ~ /ansible_host=/) { sub(/ansible_host=[^ ]+/, "ansible_host=" ip) } print }' $(INVENTORY) > $$tmp && mv $$tmp $(INVENTORY) && echo "[OK] Inventory atualizado: $(INVENTORY)"
