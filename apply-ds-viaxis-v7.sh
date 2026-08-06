
#!/bin/bash
# Aplica DS VIAXIS v1.0.0 no Produtividade PS - patch v7
# Corrige relatorio.html (charts) e habilita toggle de tema global.

set -e
APP_DIR=${APP_DIR:-/opt/produtividade-ps}
TAR_URL=https://github.com/claudio0507/produtividade-ps-ds-patch/raw/main/produtividade-ps-ds-viaxis-v7.tar.gz
BKP_DIR=/tmp/produtividade-ps-backup-v7-$(date +%Y%m%d-%H%M%S)

echo "=== 1. Backup ==="
mkdir -p "$BKP_DIR"
cp -r "$APP_DIR/templates" "$BKP_DIR/"
echo "Backup: $BKP_DIR"

echo
echo "=== 2. Baixa e extrai ==="
cd /tmp
wget -q "$TAR_URL" -O ds-viaxis-v7.tar.gz
tar -xzf ds-viaxis-v7.tar.gz
ls -la templates/

echo
echo "=== 3. Validacoes ==="
FAILED=0
check(){ if [ "$1" -eq 0 ]; then echo "  [OK] $2"; else echo "  [FAIL] $2"; FAILED=1; fi; }

grep -q 'data-system="viasset"' templates/base.html; check $? "base.html: data-system=viasset"
grep -q 'data-system="viasset"' templates/relatorio.html; check $? "relatorio.html: data-system=viasset"
grep -q '#2BB673' templates/relatorio.html; check $? "relatorio.html: acento VIASSET"
grep -q 'Segoe UI' templates/relatorio.html; check $? "relatorio.html: tipografia nativa"
grep -q 'function toggleTheme' templates/base.html; check $? "base.html: toggleTheme global"
grep -q 'function chartFont' templates/relatorio.html; check $? "relatorio.html: chartFont presente"
grep -q 'window.toggleTheme = toggleTheme' templates/relatorio.html; check $? "relatorio.html: toggleTheme exposto"
grep -q '{% for r in ranking %}' templates/relatorio.html; check $? "relatorio.html: loop ranking"
grep -q '{% for insight in insights %}' templates/relatorio.html; check $? "relatorio.html: loop insights"
grep -q '/relatorio?start=' templates/dashboard.html; check $? "dashboard.html: botao relatorio"

grep -q 'fonts.googleapis.com' templates/*.html 2>/dev/null; [ $? -ne 0 ]; check $? "nenhum template com webfonts"

grep -lP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' templates/*.html 2>/dev/null | grep -q .; [ $? -ne 0 ]; check $? "nenhum template com emoji"

grep -lE 'var\(--red\)|var\(--green\)|var\(--text[2-9]\)' templates/*.html 2>/dev/null | grep -q .; [ $? -ne 0 ]; check $? "nenhum template com vars legadas"

python3 - <<'PY' > /tmp/jinja-out.txt 2>&1
import os, sys, jinja2
errs=[]
for f in sorted(os.listdir('templates')):
    if f.endswith('.html'):
        try:
            jinja2.Environment().parse(open('templates/'+f).read())
        except Exception as e:
            errs.append((f, str(e)))
if errs:
    print('Jinja errors:')
    for f,e in errs:
        print(f'  {f}: {e}')
    sys.exit(1)
print('[OK] Jinja')
PY
if [ $? -eq 0 ]; then echo "  [OK] sintaxe Jinja valida"; else cat /tmp/jinja-out.txt; FAILED=1; fi

if [ "$FAILED" -gt 0 ]; then
  echo "=== ABORTANDO ==="
  exit 1
fi

echo
echo "=== 4. Aplica templates ==="
for f in base.html dashboard.html admin.html login.html apontamentos.html relatorio.html; do
  cp -f "templates/$f" "$APP_DIR/templates/$f"
  echo "  [OK] $f"
done

echo
echo "=== 5. Reinicia ==="
systemctl restart produtividade-ps
sleep 2

echo
echo "=== 6. Verificacoes ==="
CJAR=/tmp/cookies-v7.txt
rm -f "$CJAR"
LOGIN_CODE=$(curl -s -c "$CJAR" -X POST -d "login=admin&senha=admin123" -o /dev/null -w "%{http_code}" https://produtividade.viaxis.tech/login)
echo "  /login: HTTP $LOGIN_CODE"
ADMIN_CODE=$(curl -s -b "$CJAR" -o /dev/null -w "%{http_code}" "https://produtividade.viaxis.tech/admin?tab=tipos")
REL_CODE=$(curl -s -b "$CJAR" -o /dev/null -w "%{http_code}" "https://produtividade.viaxis.tech/relatorio?start=2026-08-01&end=2026-08-31")
echo "  /admin?tab=tipos: HTTP $ADMIN_CODE"
echo "  /relatorio?start=...: HTTP $REL_CODE"

ADMIN_HTML=$(curl -s -b "$CJAR" "https://produtividade.viaxis.tech/admin?tab=tipos")
REL_HTML=$(curl -s -b "$CJAR" "https://produtividade.viaxis.tech/relatorio?start=2026-08-01&end=2026-08-31")
echo "  admin DS: $(echo "$ADMIN_HTML" | grep -c 'data-system="viasset"')"
echo "  relatorio DS: $(echo "$REL_HTML" | grep -c 'data-system="viasset"')"
echo "  relatorio accent: $(echo "$REL_HTML" | grep -c '#2BB673')"
echo "  relatorio font: $(echo "$REL_HTML" | grep -c 'Segoe UI')"

echo
echo "=== Concluido ==="
echo "Backup: $BKP_DIR"
echo "URL: https://produtividade.viaxis.tech/relatorio?start=2026-08-01&end=2026-08-31"
echo "URL: https://produtividade.viaxis.tech/admin"
