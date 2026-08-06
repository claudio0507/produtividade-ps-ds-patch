#!/bin/bash
# Aplica o Design System VIAXIS no Produtividade PS em produção
# Repo DS: https://github.com/claudio0507/ds-viaxis-ui
# Uso: ./apply-ds-viaxis.sh
set -e

APP_DIR=${APP_DIR:-/opt/produtividade-ps}
BACKUP_DIR=/tmp/produtividade-ps-backup-$(date +%Y%m%d-%H%M%S)

echo "=== 1. Backup dos templates atuais ==="
mkdir -p "$BACKUP_DIR"
cp -r "$APP_DIR/templates" "$BACKUP_DIR/"
echo "Backup: $BACKUP_DIR"

echo ""
echo "=== 2. Extrai templates com DS aplicado ==="
# Este tar.gz contém templates/ com o design system inlinado
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
tar -xzf "$SCRIPT_DIR/produtividade-ps-ds-viaxis.tar.gz" -C "$APP_DIR/"

echo ""
echo "=== 3. Verifica atributo data-system ==="
if grep -q 'data-system="viasset"' "$APP_DIR/templates/base.html"; then
  echo "  [OK] data-system=viasset presente"
else
  echo "  [FAIL] data-system=viasset nao encontrado"
  exit 1
fi

echo ""
echo "=== 4. Verifica tokens VIAXIS ==="
if grep -q '#2BB673' "$APP_DIR/templates/base.html"; then
  echo "  [OK] Acento VIASSET (#2BB673) presente"
fi
if grep -q "Segoe UI" "$APP_DIR/templates/base.html"; then
  echo "  [OK] Tipografia nativa (Segoe UI) presente"
fi
if ! grep -q "fonts.googleapis.com" "$APP_DIR/templates/base.html"; then
  echo "  [OK] Webfonts removidas"
fi

echo ""
echo "=== 5. Reinicia servico ==="
if systemctl list-units --type=service --no-pager 2>/dev/null | grep -q produtividade-ps.service; then
  systemctl restart produtividade-ps
  echo "  [OK] produtividade-ps reiniciado"
else
  echo "  [INFO] servico systemd nao encontrado, restart manual necessario"
fi

echo ""
echo "=== Concluido ==="
echo "URL: https://produtividade.viaxis.tech/login"
echo "Backup: $BACKUP_DIR"
echo "Para reverter: cp -r $BACKUP_DIR/templates/* $APP_DIR/templates/"
