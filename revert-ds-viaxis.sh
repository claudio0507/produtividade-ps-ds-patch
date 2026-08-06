#!/bin/bash
# Reverte o patch DS VIAXIS, restaurando o backup pre-patch
set -e

BKP=/tmp/produtividade-ps-backup-20260806-132858/templates
CUR=/opt/produtividade-ps/templates

if [ ! -d "$BKP" ]; then
  echo "ERRO: backup nao encontrado em $BKP"
  exit 1
fi

echo "=== Listando backup ==="
ls -la $BKP/

echo ""
echo "=== Restaurando templates do backup ==="
cp -rf $BKP/* $CUR/

echo ""
echo "=== Reiniciando servico ==="
systemctl restart produtividade-ps

echo ""
echo "=== Concluido: app voltou ao estado pre-patch ==="
echo "URL: https://produtividade.viaxis.tech/login"
