#!/bin/bash
# Aplica DS VIAXIS v1.0.0 no Produtividade PS - patch v2 (cirúrgico)
# - Preserva relatorio.html (não estende base.html)
# - Substitui apenas os 5 templates do tar
# - Valida antes de reiniciar

set -e

APP_DIR=${APP_DIR:-/opt/produtividade-ps}
TAR_URL=https://github.com/claudio0507/produtividade-ps-ds-patch/raw/main/produtividade-ps-ds-viaxis-v2.tar.gz
BKP_DIR=/tmp/produtividade-ps-backup-v2-$(date +%Y%m%d-%H%M%S)

echo "=== 1. Backup ==="
mkdir -p "$BKP_DIR"
cp -r "$APP_DIR/templates" "$BKP_DIR/"
echo "Backup: $BKP_DIR"

echo
echo "=== 2. Inventário pré-patch (relatorio.html existe?) ==="
if [ -f "$APP_DIR/templates/relatorio.html" ]; then
  SIZE=$(stat -c%s "$APP_DIR/templates/relatorio.html")
  echo "  [OK] relatorio.html preservado ($SIZE bytes)"
else
  echo "  [WARN] relatorio.html não existe — rota /relatorio pode estar quebrada"
fi

echo
echo "=== 3. Baixa e extrai ==="
cd /tmp
wget -q "$TAR_URL" -O ds-viaxis-v2.tar.gz
tar -xzf ds-viaxis-v2.tar.gz
ls -la templates/

echo
echo "=== 4. Validações ==="
FAILED=0

# 4.1. base.html com data-system=viasset
if grep -q 'data-system="viasset"' templates/base.html; then
  echo "  [OK] base.html: data-system=viasset"
else
  echo "  [FAIL] base.html sem data-system=viasset"
  FAILED=1
fi

# 4.2. Acento VIASSET
if grep -q '#2BB673' templates/base.html; then
  echo "  [OK] base.html: acento VIASSET (#2BB673)"
else
  echo "  [FAIL] base.html sem acento VIASSET"
  FAILED=1
fi

# 4.3. Sem webfonts
if ! grep -q 'fonts.googleapis.com' templates/base.html; then
  echo "  [OK] base.html: sem webfonts"
else
  echo "  [FAIL] base.html ainda tem webfonts"
  FAILED=1
fi

# 4.4. Sem emoji em templates
if grep -lP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' templates/*.html 2>/dev/null; then
  echo "  [FAIL] emoji encontrado em algum template"
  FAILED=1
else
  echo "  [OK] sem emojis em templates"
fi

# 4.5. Sem vars legadas
if grep -lE 'var\(--red\)|var\(--green\)|var\(--text[2-9]\)' templates/*.html 2>/dev/null; then
  echo "  [FAIL] vars legadas --red/--green/--text2 encontradas"
  FAILED=1
else
  echo "  [OK] vars CSS legadas removidas"
fi

# 4.6. dashboard tem botão de relatório
if grep -q '/relatorio?start=' templates/dashboard.html; then
  echo "  [OK] dashboard.html: botão de relatório preservado"
else
  echo "  [FAIL] dashboard.html sem botão de relatório"
  FAILED=1
fi

# 4.7. apontamentos.html renderiza (sintaxe Jinja)
if grep -q '{% block content %}' templates/apontamentos.html && grep -q '{% endblock %}' templates/apontamentos.html; then
  echo "  [OK] apontamentos.html: blocos Jinja válidos"
else
  echo "  [FAIL] apontamentos.html: blocos Jinja quebrados"
  FAILED=1
fi

if [ "$FAILED" -gt 0 ]; then
  echo
  echo "=== ABORTANDO: $FAILED validação(ões) falharam ==="
  echo "Templates NÃO foram sobrescritos. Backup em $BKP_DIR"
  exit 1
fi

echo
echo "=== 5. Sobrescreve templates (preserva relatorio.html se existir) ==="
# Copia cada template individualmente (relatorio.html nao esta no tar)
for f in base.html dashboard.html admin.html login.html apontamentos.html; do
  if [ -f "templates/$f" ]; then
    cp -f "templates/$f" "$APP_DIR/templates/$f"
    echo "  [OK] $f"
  else
    echo "  [FAIL] $f ausente no tar"
    exit 1
  fi
done

# Garante que relatorio.html continua intacto
if [ -f "$BKP_DIR/templates/relatorio.html" ] && [ ! -f "$APP_DIR/templates/relatorio.html" ]; then
  cp "$BKP_DIR/templates/relatorio.html" "$APP_DIR/templates/relatorio.html"
  echo "  [OK] relatorio.html restaurado do backup"
fi

echo
echo "=== 6. Reinicia servico ==="
if systemctl list-units --type=service --no-pager 2>/dev/null | grep -q produtividade-ps.service; then
  systemctl restart produtividade-ps
  echo "  [OK] produtividade-ps reiniciado"
else
  echo "  [INFO] servico systemd nao encontrado - restart manual"
fi

echo
echo "=== 7. Verificacao pos-deploy ==="
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://produtividade.viaxis.tech/login)
echo "  /login HTTP: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
  if curl -s https://produtividade.viaxis.tech/login | grep -q 'data-system="viasset"'; then
    echo "  [OK] data-system=viasset servido em produção"
  fi
  if curl -s https://produtividade.viaxis.tech/login | grep -q '#2BB673'; then
    echo "  [OK] acento VIASSET servido em produção"
  fi
fi

echo
echo "=== Concluido ==="
echo "URL: https://produtividade.viaxis.tech/login"
echo "URL: https://produtividade.viaxis.tech/dashboard (autenticado)"
echo "URL: https://produtividade.viaxis.tech/relatorio (autenticado)"
echo "Backup: $BKP_DIR"
echo "Para reverter: cp -rf $BKP_DIR/templates/* $APP_DIR/templates/ && systemctl restart produtividade-ps"
