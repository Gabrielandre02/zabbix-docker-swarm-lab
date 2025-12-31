#!/bin/bash

# Configurações
VAGRANT_DIR="." # Altere para o caminho do diretório do Vagrantfile, se necessário
ANSIBLE_PLAYBOOK="playbooks/deploy-full-zabbix.yml"
ANSIBLE_INVENTORY="inventory/hosts.ini"
DEFAULT_IP="10.0.0.22"

# Exportar variáveis de ambiente
export IPS_VMS="${IPS_VMS:-$DEFAULT_IP}"

# Função para verificar o status de comandos
check_status() {
  if [ $? -ne 0 ]; then
    echo "[ERRO] $1"
    exit 1
  else
    echo "[OK] $1"
  fi
}

# Função para verificar a existência de arquivos necessários
check_file_exists() {
  if [ ! -f "$1" ]; then
    echo "[ERRO] Arquivo não encontrado: $1"
    exit 1
  else
    echo "[OK] Arquivo encontrado: $1"
  fi
}

# 1. Verificar a existência do diretório do Vagrant
if [ ! -d "$VAGRANT_DIR" ]; then
  echo "[ERRO] Diretório do Vagrant não encontrado: $VAGRANT_DIR"
  exit 1
fi

# Entrar no diretório do Vagrant
cd "$VAGRANT_DIR" || { echo "[ERRO] Não foi possível acessar o diretório $VAGRANT_DIR"; exit 1; }

# 2. Iniciar a máquina virtual com Vagrant
echo "==> Iniciando a máquina virtual com Vagrant..."
vagrant up
check_status "Máquina virtual iniciada com sucesso."

# 3. Validar se a máquina está em execução
echo "==> Validando se a máquina está ativa..."
vagrant status | grep -q "running (virtualbox)"
check_status "Máquina virtual está ativa."

# 4. Atualizar o inventário do Ansible com o IP
echo "==> Atualizando o inventário do Ansible com o IP $IPS_VMS..."
sed -i "s/\$IPS_VMS/$IPS_VMS/g" "$ANSIBLE_INVENTORY"
check_status "Inventário do Ansible atualizado com sucesso."

# 5. Verificar se o inventário e o playbook do Ansible existem
echo "==> Verificando arquivos do Ansible..."
check_file_exists "$ANSIBLE_INVENTORY"
check_file_exists "$ANSIBLE_PLAYBOOK"

# 6. Executar o Ansible Playbook
echo "==> Executando o Ansible Playbook..."
ansible-playbook -i "$ANSIBLE_INVENTORY" "$ANSIBLE_PLAYBOOK"
check_status "Playbook Ansible executado com sucesso."

# 7. Mensagem final
echo "==> Validação completa. A máquina está criada e o playbook foi executado com sucesso."
exit 0
