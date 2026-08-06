
#!/bin/bash
set -e
APP_DIR=${APP_DIR:-/opt/produtividade-ps}
TAR_URL=https://github.com/claudio0507/produtividade-ps-ds-patch/raw/main/produtividade-ps-ds-viaxis-v8.tar.gz
BKP_DIR=/tmp/produtividade-ps-backup-v8-$(date +%Y%m%d-%H%M%S)

echo "=== 1. Backup ==="
mkdir -p "$BKP_DIR"
cp -r "$APP_DIR/templates" "$BKP_DIR/"
echo "Backup: $BKP_DIR"

echo "=== 2. Baixa e extrai ==="
cd /tmp
wget -q "$TAR_URL" -O ds-viaxis-v8.tar.gz
tar -xzf ds-viaxis-v8.tar.gz
ls -la templates/

echo "=== 3. Validacoes ==="
FAILED=0
check(){ if [ "$1" -eq 0 ]; then echo "  [OK] $2"; else echo "  [FAIL] $2"; FAILED=1; fi; }

grep -q 'data-system="viasset"' templates/base.html; check $? 'base.html: data-system=viasset'
grep -q 'window.toggleTheme = function()' templates/base.html; check $? 'base.html: toggleTheme global'
grep -q 'data-system="viasset"' templates/relatorio.html; check $? 'relatorio.html: data-system=viasset'
grep -q 'window.toggleTheme = toggleTheme;' templates/relatorio.html; check $? 'relatorio.html: toggleTheme global'
grep -q 'function chartFont(){ return { family: "'Segoe UI',system-ui,-apple-system,sans-serif", size: 10 }; }' templates/relatorio.html; check $? 'relatorio.html: chartFont'
grep -q '{% for r in ranking %}' templates/relatorio.html; check $? 'relatorio.html: loop ranking'
grep -q '{% for insight in insights %}' templates/relatorio.html; check $? 'relatorio.html: loop insights'
grep -q '/relatorio?start=' templates/dashboard.html; check $? 'dashboard.html: botao relatorio'
! grep -q 'fonts.googleapis.com' templates/*.html 2>/dev/null; check $? 'sem webfonts'
! grep -lP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' templates/*.html 2>/dev/null | grep -q .; check $? 'sem emojis'
! grep -lE 'var\(--red\)|var\(--green\)|var\(--text[2-9]\)' templates/*.html 2>/dev/null | grep -q .; check $? 'sem vars legadas'
python3 - <<'PY' > /tmp/jinja-v8.txt 2>&1
import os, sys, jinja2
errs=[]
for f in sorted(os.listdir('templates')):
    if f.endswith('.html'):
        try:
            jinja2.Environment().parse(open('templates/'+f).read())
        except Exception as e:
            errs.append((f, str(e)))
if errs:
    for f,e in errs: print(f'{f}: {e}')
    sys.exit(1)
print('[OK] Jinja')
PY
if [ $? -eq 0 ]; then echo '  [OK] Jinja'; else cat /tmp/jinja-v8.txt; FAILED=1; fi
[ "$FAILED" -eq 0 ]

echo "=== 4. Aplica ==="
for f in base.html dashboard.html admin.html login.html apontamentos.html relatorio.html; do cp -f "templates/$f" "$APP_DIR/templates/$f"; echo "  [OK] $f"; done

echo "=== 5. Reinicia ==="
systemctl restart produtividade-ps
sleep 2

echo "=== 6. Verificacoes ==="
CJAR=/tmp/cookies-v8.txt
rm -f "$CJAR"
curl -s -c "$CJAR" -X POST -d "login=admin&senha=admin123" -o /dev/null https://produtividade.viaxis.tech/login
ADMIN_HTML=$(curl -s -b "$CJAR" 'https://produtividade.viaxis.tech/admin?tab=tipos')
REL_HTML=$(curl -s -b "$CJAR" 'https://produtividade.viaxis.tech/relatorio?start=2026-08-01&end=2026-08-31')
echo "  admin DS: $(echo "$ADMIN_HTML" | grep -c 'data-system="viasset"')"
echo "  relatorio DS: $(echo "$REL_HTML" | grep -c 'data-system="viasset"')"
echo "  relatorio toggle: $(echo "$REL_HTML" | grep -c 'window.toggleTheme = toggleTheme;')"
echo "  relatorio chartFont: $(echo "$REL_HTML" | grep -c 'function chartFont(){ return { family:')"
echo "  relatorio chart.js: $(echo "$REL_HTML" | grep -c 'chart.js')"

echo "=== Concluido ==="
echo "Backup: $BKP_DIR"
