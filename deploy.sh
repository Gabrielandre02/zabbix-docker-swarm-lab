#!/bin/bash

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAGRANT_DIR="$SCRIPT_DIR"
VAGRANT_VM_NAME="zabbixlnx01"
ANSIBLE_PLAYBOOK="$SCRIPT_DIR/ansible-deploy-full-zabbix/playbooks/deploy-full-zabbix.yml"
ANSIBLE_INVENTORY="$SCRIPT_DIR/ansible-deploy-full-zabbix/inventory/hosts.ini"
ANSIBLE_CONFIG="$SCRIPT_DIR/ansible-deploy-full-zabbix/ansible.cfg"
ANSIBLE_ROLES_PATH="$SCRIPT_DIR/ansible-deploy-full-zabbix/roles"
DESTROY_ON_UID_MISMATCH="${DESTROY_ON_UID_MISMATCH:-true}"
DEFAULT_HOST_PORT="8080"

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERRO] Comando não encontrado no PATH: $1"
    exit 1
  fi
}

clean_known_host() {
  local host="$1"
  if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen -R "$host" >/dev/null 2>&1 || true
  fi
}

clean_known_host_with_port() {
  local host="$1"
  local port="$2"
  if [ -n "$host" ] && [ -n "$port" ]; then
    clean_known_host "[$host]:$port"
  fi
}

wait_for_ssh() {
  local vm_name="$1"
  local timeout="${SSH_WAIT_TIMEOUT:-300}"
  local interval=5
  local start_ts
  local cfg ssh_user ssh_host ssh_port ssh_key

  cfg="$(vagrant ssh-config "$vm_name" 2>/dev/null)" || return 1
  ssh_user="$(echo "$cfg" | awk '/^  User /{print $2}')"
  ssh_host="$(echo "$cfg" | awk '/^  HostName /{print $2}')"
  ssh_port="$(echo "$cfg" | awk '/^  Port /{print $2}')"
  ssh_key="$(echo "$cfg" | awk '/^  IdentityFile /{print $2}')"

  if [ -z "$ssh_user" ] || [ -z "$ssh_host" ] || [ -z "$ssh_port" ] || [ -z "$ssh_key" ]; then
    echo "[ERRO] Não foi possível obter dados de SSH via 'vagrant ssh-config'."
    return 1
  fi

  start_ts="$(date +%s)"
  while true; do
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$ssh_key" -p "$ssh_port" "$ssh_user@$ssh_host" "true" >/dev/null 2>&1; then
      return 0
    fi
    if [ $(( $(date +%s) - start_ts )) -ge "$timeout" ]; then
      echo "[ERRO] Timeout aguardando SSH ficar disponível ($timeout s)."
      return 1
    fi
    sleep "$interval"
  done
}

update_inventory_from_vagrant() {
  local vm_name="$1"
  local inventory="$2"
  local cfg ssh_user ssh_host ssh_port ssh_key
  local tmp_file

  cfg="$(vagrant ssh-config "$vm_name" 2>/dev/null)" || return 1
  ssh_user="$(echo "$cfg" | awk '/^  User /{print $2}')"
  ssh_host="$(echo "$cfg" | awk '/^  HostName /{print $2}')"
  ssh_port="$(echo "$cfg" | awk '/^  Port /{print $2}')"
  ssh_key="$(echo "$cfg" | awk '/^  IdentityFile /{print $2}')"

  if [ -z "$ssh_user" ] || [ -z "$ssh_host" ] || [ -z "$ssh_port" ] || [ -z "$ssh_key" ]; then
    return 1
  fi

  tmp_file="$(mktemp)"
  awk -v host="$ssh_host" -v port="$ssh_port" -v user="$ssh_user" -v key="$ssh_key" '
    $0 ~ /^host01[[:space:]]/ {
      if ($0 !~ /ansible_host=/) { $0 = $0 " ansible_host=" host }
      if ($0 !~ /ansible_port=/) { $0 = $0 " ansible_port=" port }
      if ($0 !~ /ansible_user=/) { $0 = $0 " ansible_user=" user }
      if ($0 !~ /ansible_ssh_private_key_file=/) { $0 = $0 " ansible_ssh_private_key_file=" key }
      gsub(/ansible_host=[^ ]+/, "ansible_host=" host)
      gsub(/ansible_port=[^ ]+/, "ansible_port=" port)
      gsub(/ansible_user=[^ ]+/, "ansible_user=" user)
      gsub(/ansible_ssh_private_key_file=[^ ]+/, "ansible_ssh_private_key_file=" key)
    }
    { print }
  ' "$inventory" > "$tmp_file"
  mv "$tmp_file" "$inventory"
}

get_vm_ip() {
  vagrant ssh "$VAGRANT_VM_NAME" -c 'hostname -I | awk "{print \$1}"' 2>/dev/null | tr -d '\r'
}
find_free_port() {
  local port="$1"
  while lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; do
    port=$((port + 1))
  done
  echo "$port"
}

check_file_exists() {
  if [ ! -f "$1" ]; then
    echo "[ERRO] Arquivo não encontrado: $1"
    exit 1
  fi
  echo "[OK] Arquivo encontrado: $1"
}

run_step() {
  local ok_msg="$1"
  local err_msg="$2"
  shift 2
  "$@"
  if [ $? -ne 0 ]; then
    echo "[ERRO] $err_msg"
    exit 1
  fi
  echo "[OK] $ok_msg"
}

is_vm_running() {
  vagrant status --machine-readable | awk -F, '$3=="state" {print $4}' | grep -q "^running$"
}

handle_vagrant_up() {
  local output_file
  local status
  local vm_uid
  local current_uid

  output_file="$(mktemp)"
  vagrant up >"$output_file" 2>&1
  status=$?
  if [ $status -eq 0 ]; then
    rm -f "$output_file"
    echo "[OK] Máquina virtual iniciada com sucesso."
    return 0
  fi

  if grep -q "VirtualBox VM was created with a user that doesn't match the" "$output_file"; then
    vm_uid="$(awk -F': ' '/UID used to create the VM/{print $2}' "$output_file")"
    current_uid="$(awk -F': ' '/Your UID is/{print $2}' "$output_file")"
    echo "[ERRO] VM foi criada por outro usuário (UID ${vm_uid:-desconhecido}). Seu UID é ${current_uid:-desconhecido}."
    if [ "$DESTROY_ON_UID_MISMATCH" = "true" ]; then
      echo "==> Removendo VM existente para recriar com o usuário atual..."
      vagrant destroy -f "$VAGRANT_VM_NAME" >/dev/null 2>&1
      if [ $? -ne 0 ]; then
        cat "$output_file"
        echo "[ERRO] Falha ao remover a VM existente. Execute 'vagrant destroy -f' manualmente."
        rm -f "$output_file"
        exit 1
      fi
      echo "[OK] VM removida com sucesso. Recriando..."
      vagrant up >"$output_file" 2>&1
      status=$?
      if [ $status -ne 0 ]; then
        cat "$output_file"
        echo "[ERRO] Falha ao iniciar a máquina virtual com Vagrant."
        rm -f "$output_file"
        exit 1
      fi
      rm -f "$output_file"
      echo "[OK] Máquina virtual iniciada com sucesso."
      return 0
    fi
    cat "$output_file"
    rm -f "$output_file"
    exit 1
  fi

  cat "$output_file"
  rm -f "$output_file"
  echo "[ERRO] Falha ao iniciar a máquina virtual com Vagrant."
  exit 1
}

# 1. Verificar comandos e arquivos essenciais
check_command vagrant
check_command ansible-playbook
check_command VBoxManage
check_command ssh
check_file_exists "$VAGRANT_DIR/Vagrantfile"

# 2. Verificar a existência do diretório do Vagrant
if [ ! -d "$VAGRANT_DIR" ]; then
  echo "[ERRO] Diretório do Vagrant não encontrado: $VAGRANT_DIR"
  exit 1
fi

# Entrar no diretório do Vagrant
cd "$VAGRANT_DIR" || { echo "[ERRO] Não foi possível acessar o diretório $VAGRANT_DIR"; exit 1; }

# 3. Iniciar a máquina virtual com Vagrant
echo "==> Iniciando a máquina virtual com Vagrant..."
if [ -z "${VAGRANT_HOST_PORT:-}" ]; then
  VAGRANT_HOST_PORT="$(find_free_port "$DEFAULT_HOST_PORT")"
  export VAGRANT_HOST_PORT
  echo "==> Usando porta do host para forward: $VAGRANT_HOST_PORT"
fi
handle_vagrant_up

# 4. Validar se a máquina está em execução
echo "==> Validando se a máquina está ativa..."
if is_vm_running; then
  echo "[OK] Máquina virtual está ativa."
else
  echo "[ERRO] Máquina virtual não está ativa."
  exit 1
fi

# 5. Aguardar SSH ficar disponível
echo "==> Aguardando SSH ficar disponível na VM..."
if wait_for_ssh "$VAGRANT_VM_NAME"; then
  echo "[OK] SSH disponível."
else
  echo "[ERRO] SSH não ficou disponível a tempo."
  exit 1
fi

# 6. Atualizar o inventário do Ansible com dados do Vagrant
echo "==> Atualizando o inventário do Ansible com dados do Vagrant..."
if update_inventory_from_vagrant "$VAGRANT_VM_NAME" "$ANSIBLE_INVENTORY"; then
  echo "[OK] Inventário do Ansible atualizado com sucesso."
else
  echo "[ERRO] Não foi possível atualizar o inventory via vagrant ssh-config."
  exit 1
fi

vm_ip="$(get_vm_ip)"
if [ -n "$vm_ip" ]; then
  echo "==> IP da VM: $vm_ip"
  echo "==> Use esse IP para mapear o DNS de acesso (ex.: zabbix.seu-dominio)."
fi

# 7. Verificar se o inventário e o playbook do Ansible existem
echo "==> Verificando arquivos do Ansible..."
check_file_exists "$ANSIBLE_INVENTORY"
check_file_exists "$ANSIBLE_PLAYBOOK"

# 8. Executar o Ansible Playbook
echo "==> Executando o Ansible Playbook..."
echo "==> Limpando chave SSH antiga (se existir)..."
ssh_cfg="$(vagrant ssh-config "$VAGRANT_VM_NAME" 2>/dev/null)"
ssh_host="$(echo "$ssh_cfg" | awk '/^  HostName /{print $2}')"
ssh_port="$(echo "$ssh_cfg" | awk '/^  Port /{print $2}')"
clean_known_host "$ssh_host"
clean_known_host_with_port "$ssh_host" "$ssh_port"
run_step "Playbook Ansible executado com sucesso." "Falha ao executar o Playbook Ansible." env ANSIBLE_CONFIG="$ANSIBLE_CONFIG" ANSIBLE_ROLES_PATH="$ANSIBLE_ROLES_PATH" ansible-playbook -i "$ANSIBLE_INVENTORY" "$ANSIBLE_PLAYBOOK"

# 9. Mensagem final
echo "==> Validação completa. A máquina está criada e o playbook foi executado com sucesso."
exit 0
