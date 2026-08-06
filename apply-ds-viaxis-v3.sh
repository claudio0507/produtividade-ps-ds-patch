#!/bin/bash
# Aplica DS VIAXIS v1.0.0 no Produtividade PS - patch v3
# - admin.html reconstruido (corrige Internal Server Error em /admin)
# - Preserva relatorio.html (standalone, NAO estende base.html)
# - Substitui apenas os 5 templates do tar

set -e

APP_DIR=${APP_DIR:-/opt/produtividade-ps}
TAR_URL=https://github.com/claudio0507/produtividade-ps-ds-patch/raw/main/produtividade-ps-ds-viaxis-v3.tar.gz
BKP_DIR=/tmp/produtividade-ps-backup-v3-$(date +%Y%m%d-%H%M%S)

echo "=== 1. Backup ==="
mkdir -p "$BKP_DIR"
cp -r "$APP_DIR/templates" "$BKP_DIR/"
echo "Backup: $BKP_DIR"

echo
echo "=== 2. Inventario pre-patch ==="
ls -la "$APP_DIR/templates/"

echo
echo "=== 3. Baixa e extrai ==="
cd /tmp
wget -q "$TAR_URL" -O ds-viaxis-v3.tar.gz
tar -xzf ds-viaxis-v3.tar.gz
ls -la templates/

echo
echo "=== 4. Validacoes ==="
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
EMOJI_FOUND=$(grep -lP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' templates/*.html 2>/dev/null | wc -l)
if [ "$EMOJI_FOUND" -eq 0 ]; then
  echo "  [OK] sem emojis em templates"
else
  echo "  [FAIL] emoji encontrado em $EMOJI_FOUND template(s)"
  FAILED=1
fi

# 4.5. Sem vars legadas
LEGACY=$(grep -lE 'var\(--red\)|var\(--green\)|var\(--text[2-9]\)' templates/*.html 2>/dev/null | wc -l)
if [ "$LEGACY" -eq 0 ]; then
  echo "  [OK] vars CSS legadas removidas"
else
  echo "  [FAIL] vars legadas em $LEGACY template(s)"
  FAILED=1
fi

# 4.6. dashboard tem botao de relatorio
if grep -q '/relatorio?start=' templates/dashboard.html; then
  echo "  [OK] dashboard.html: botao de relatorio preservado"
else
  echo "  [FAIL] dashboard.html sem botao de relatorio"
  FAILED=1
fi

# 4.7. admin tem todas as 5 abas (equipes/obras/supervisores/causas/tipos)
ADMIN_TABS=$(grep -c "tab-btn.*tab==" templates/admin.html)
if [ "$ADMIN_TABS" -ge 5 ]; then
  echo "  [OK] admin.html: 5 abas (equipes/obras/supervisores/causas/tipos)"
else
  echo "  [FAIL] admin.html: apenas $ADMIN_TABS abas"
  FAILED=1
fi

# 4.8. Valida sintaxe Jinja
python3 -c "
import jinja2
import os
errs = 0
for f in os.listdir('templates'):
    if not f.endswith('.html'):
        continue
    try:
        jinja2.Environment().parse(open('templates/'+f).read())
    except jinja2.TemplateSyntaxError as e:
        print(f'  [FAIL] {f}: {e}')
        errs += 1
exit(errs)
" || FAILED=1

if [ "$FAILED" -gt 0 ]; then
  echo
  echo "=== ABORTANDO: $FAILED validacao(oes) falharam ==="
  echo "Templates NAO foram sobrescritos. Backup em $BKP_DIR"
  exit 1
fi

echo
echo "=== 5. Sobrescreve templates (preserva relatorio.html) ==="
for f in base.html dashboard.html admin.html login.html apontamentos.html; do
  if [ -f "templates/$f" ]; then
    cp -f "templates/$f" "$APP_DIR/templates/$f"
    echo "  [OK] $f"
  fi
done

# Garante relatorio.html preservado (nao foi sobrescrito - nao esta no tar)
if [ -f "$BKP_DIR/templates/relatorio.html" ]; then
  REL_SIZE=$(stat -c%s "$APP_DIR/templates/relatorio.html")
  echo "  [OK] relatorio.html preservado ($REL_SIZE bytes)"
fi

echo
echo "=== 6. Reinicia servico ==="
systemctl restart produtividade-ps && echo "  [OK] reiniciado" || echo "  [WARN] servico nao reiniciou"

echo
echo "=== 7. Verificacao pos-deploy ==="
sleep 2
for path in /login /admin; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" https://produtividade.viaxis.tech$path)
  echo "  GET $path: HTTP $CODE"
done

echo
echo "=== Concluido ==="
echo "URL: https://produtividade.viaxis.tech/login"
echo "Backup: $BKP_DIR"
echo "Reversao: cp -rf $BKP_DIR/templates/* $APP_DIR/templates/ && systemctl restart produtividade-ps"
