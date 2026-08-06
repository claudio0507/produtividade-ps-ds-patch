#!/bin/bash
# Aplica DS VIAXIS v1.0.0 no Produtividade PS - patch v6
# Objetivo: atualizar relatorio.html + corrigir admin.html sem rollback agressivo.

set -e
APP_DIR=${APP_DIR:-/opt/produtividade-ps}
TAR_URL=https://github.com/claudio0507/produtividade-ps-ds-patch/raw/main/produtividade-ps-ds-viaxis-v5.tar.gz
BKP_DIR=/tmp/produtividade-ps-backup-v6-$(date +%Y%m%d-%H%M%S)

echo "=== 1. Backup ==="
mkdir -p "$BKP_DIR"
cp -r "$APP_DIR/templates" "$BKP_DIR/"
echo "Backup: $BKP_DIR"

echo
echo "=== 2. Baixa e extrai ==="
cd /tmp
wget -q "$TAR_URL" -O ds-viaxis-v6.tar.gz
tar -xzf ds-viaxis-v6.tar.gz
ls -la templates/

echo
echo "=== 3. Checagens rapidas ==="
for f in base.html dashboard.html admin.html login.html apontamentos.html relatorio.html; do
  if [ ! -f "templates/$f" ]; then echo "[FAIL] missing $f"; exit 1; fi
  echo "  [OK] $f ($(stat -c%s templates/$f) bytes)"
done

grep -q 'data-system="viasset"' templates/base.html && echo "  [OK] base DS"
grep -q 'data-system="viasset"' templates/relatorio.html && echo "  [OK] relatorio DS"
grep -q '#2BB673' templates/relatorio.html && echo "  [OK] relatorio accent"
grep -q 'Segoe UI' templates/relatorio.html && echo "  [OK] relatorio font"
grep -q '{% for r in ranking %}' templates/relatorio.html && echo "  [OK] relatorio loop ranking"
grep -q '{% for insight in insights %}' templates/relatorio.html && echo "  [OK] relatorio loop insights"

echo
echo "=== 4. Jinja valido ==="
python3 - <<'PY'
import os, sys
import jinja2
errs = []
for f in sorted(os.listdir('templates')):
    if not f.endswith('.html'):
        continue
    text = open('templates/'+f).read()
    try:
        jinja2.Environment().parse(text)
    except Exception as e:
        errs.append((f, str(e)))
if errs:
    print('Jinja errors:')
    for f,e in errs:
        print(f'  {f}: {e}')
    sys.exit(1)
print('[OK] todos os templates com Jinja valido')
PY

echo
echo "=== 5. Aplica templates ==="
for f in base.html dashboard.html admin.html login.html apontamentos.html relatorio.html; do
  cp -f "templates/$f" "$APP_DIR/templates/$f"
  echo "  [OK] $f"
done

echo
echo "=== 6. Reinicia servico ==="
systemctl restart produtividade-ps
sleep 2

echo
echo "=== 7. Verificacao ==="
CJAR=/tmp/cookies-v6.txt
rm -f "$CJAR"
LOGIN_CODE=$(curl -s -c "$CJAR" -X POST -d "login=admin&senha=admin123" -o /dev/null -w "%{http_code}" https://produtividade.viaxis.tech/login)
echo "  /login: HTTP $LOGIN_CODE"
for path in "/admin?tab=tipos" "/relatorio?start=2026-08-01&end=2026-08-31"; do
  CODE=$(curl -s -b "$CJAR" -o /dev/null -w "%{http_code}" "https://produtividade.viaxis.tech${path}")
  echo "  ${path}: HTTP $CODE"
done

ADMIN_HTML=$(curl -s -b "$CJAR" "https://produtividade.viaxis.tech/admin?tab=tipos")
REL_HTML=$(curl -s -b "$CJAR" "https://produtividade.viaxis.tech/relatorio?start=2026-08-01&end=2026-08-31")

echo
echo "=== 8. Marcadores em producao ==="
echo "  admin DS: $(echo "$ADMIN_HTML" | grep -c 'data-system="viasset"')"
echo "  relatorio DS: $(echo "$REL_HTML" | grep -c 'data-system="viasset"')"
echo "  relatorio accent: $(echo "$REL_HTML" | grep -c '#2BB673')"
echo "  relatorio font: $(echo "$REL_HTML" | grep -c 'Segoe UI')"

echo
echo "=== 9. Logs se admin falhar ==="
if echo "$ADMIN_HTML" | grep -qi 'Internal Server Error'; then
  echo '  [FAIL] admin ainda retorna 500'
  journalctl -u produtividade-ps -n 80 --no-pager | tail -80
  echo
  echo "Backup manual: $BKP_DIR"
  exit 2
fi

echo "=== Concluido ==="
echo "Backup: $BKP_DIR"
echo "URL: https://produtividade.viaxis.tech/admin"
echo "URL: https://produtividade.viaxis.tech/relatorio?start=2026-08-01&end=2026-08-31"
