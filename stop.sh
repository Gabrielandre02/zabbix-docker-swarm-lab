#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAGRANT_DIR="$SCRIPT_DIR"
VAGRANT_VM_NAME="zabbixlnx01"

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERRO] Comando não encontrado no PATH: $1"
    exit 1
  fi
}

check_command vagrant

if [ ! -d "$VAGRANT_DIR" ]; then
  echo "[ERRO] Diretório do Vagrant não encontrado: $VAGRANT_DIR"
  exit 1
fi

cd "$VAGRANT_DIR" || { echo "[ERRO] Não foi possível acessar o diretório $VAGRANT_DIR"; exit 1; }

echo "==> Parando a VM do Vagrant..."
vagrant halt "$VAGRANT_VM_NAME"
if [ $? -ne 0 ]; then
  echo "[ERRO] Falha ao parar a VM."
  exit 1
fi

echo "==> VM parada com sucesso."
