#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAGRANT_DIR="$SCRIPT_DIR"
VAGRANT_VM_NAME="zabbixlnx01"
REMOVE_VAGRANT_STATE="${REMOVE_VAGRANT_STATE:-true}"

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERRO] Comando não encontrado no PATH: $1"
    exit 1
  fi
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

vm_exists() {
  VBoxManage list vms | awk -v name="\"$1\"" '$0 ~ name {found=1} END {exit !found}'
}

# 1. Verificar comandos e diretório
check_command vagrant
check_command VBoxManage

if [ ! -d "$VAGRANT_DIR" ]; then
  echo "[ERRO] Diretório do Vagrant não encontrado: $VAGRANT_DIR"
  exit 1
fi

cd "$VAGRANT_DIR" || { echo "[ERRO] Não foi possível acessar o diretório $VAGRANT_DIR"; exit 1; }

# 2. Remover a VM, se existir
if vm_exists "$VAGRANT_VM_NAME"; then
  echo "==> Removendo a máquina virtual do Vagrant..."
  run_step "Máquina virtual removida com sucesso." "Falha ao remover a máquina virtual." vagrant destroy -f "$VAGRANT_VM_NAME"
else
  echo "[OK] Nenhuma VM '$VAGRANT_VM_NAME' encontrada no VirtualBox."
fi

# 3. Limpar estado local do Vagrant (opcional)
if [ "$REMOVE_VAGRANT_STATE" = "true" ] && [ -d ".vagrant" ]; then
  echo "==> Removendo estado local do Vagrant (.vagrant)..."
  run_step "Estado local removido com sucesso." "Falha ao remover estado local do Vagrant." rm -rf ".vagrant"
fi

echo "==> Infra removida com sucesso."
exit 0
