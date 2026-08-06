
#!/bin/bash
set -euo pipefail
APP_DIR=${APP_DIR:-/opt/produtividade-ps}
TAR_URL=https://github.com/claudio0507/produtividade-ps-ds-patch/raw/main/produtividade-ps-ds-viaxis-v9.tar.gz
BKP_DIR=/tmp/produtividade-ps-backup-v9-$(date +%Y%m%d-%H%M%S)

echo "=== 1. Backup ==="
mkdir -p "$BKP_DIR"
cp -r "$APP_DIR/templates" "$BKP_DIR/"
echo "Backup: $BKP_DIR"

echo "=== 2. Baixa e extrai ==="
cd /tmp
wget -q "$TAR_URL" -O ds-viaxis-v9.tar.gz
tar -xzf ds-viaxis-v9.tar.gz
ls -la templates/

echo "=== 3. Validacoes (python) ==="
python3 - <<'PY'
from pathlib import Path
import os, sys, jinja2, re
files = ['base.html','dashboard.html','admin.html','login.html','apontamentos.html','relatorio.html']
req = {
    'base.html': ['data-system="viasset"', 'window.toggleTheme = function()', '#2BB673', 'Segoe UI'],
    'dashboard.html': ['/relatorio?start=', 'data-system="viasset"'],
    'admin.html': ['{% for t in tipos %}'],
    'relatorio.html': ['data-system="viasset"', '#2BB673', 'Segoe UI', 'window.toggleTheme = toggleTheme;', 'function chartFont(){ return { family: "'Segoe UI',system-ui,-apple-system,sans-serif", size: 10 }; }', '{% for r in ranking %}', '{% for insight in insights %}', 'chart.js'],
}
errs = []
for f in files:
    text = Path('templates/'+f).read_text(errors='replace')
    try:
        jinja2.Environment().parse(text)
    except Exception as e:
        errs.append(f'Jinja {f}: {e}')
    for needle in req.get(f, []):
        if needle not in text:
            errs.append(f'Missing in {f}: {needle}')
# global checks
all_text = ''.join(Path('templates/'+f).read_text(errors='replace') for f in files)
if 'fonts.googleapis.com' in all_text:
    errs.append('webfonts present')
if re.search(r'var\(--red\)|var\(--green\)|var\(--text[2-9]\)', all_text):
    errs.append('legacy CSS vars present')
if re.search(r'[🌀-🫿☀-➿]', all_text):
    errs.append('emoji present')
if errs:
    print('
'.join(errs))
    sys.exit(1)
print('[OK] validacoes OK')
PY

echo "=== 4. Aplica templates ==="
for f in base.html dashboard.html admin.html login.html apontamentos.html relatorio.html; do
  cp -f "templates/$f" "$APP_DIR/templates/$f"
  echo "  [OK] $f"
done

echo "=== 5. Reinicia ==="
systemctl restart produtividade-ps
sleep 2

echo "=== 6. Verificacoes HTTP ==="
CJAR=/tmp/cookies-v9.txt
rm -f "$CJAR"
curl -s -c "$CJAR" -X POST -d "login=admin&senha=admin123" -o /dev/null https://produtividade.viaxis.tech/login
ADMIN_CODE=$(curl -s -b "$CJAR" -o /dev/null -w "%{http_code}" 'https://produtividade.viaxis.tech/admin?tab=tipos')
REL_CODE=$(curl -s -b "$CJAR" -o /dev/null -w "%{http_code}" 'https://produtividade.viaxis.tech/relatorio?start=2026-08-01&end=2026-08-31')
echo "  /admin?tab=tipos: HTTP $ADMIN_CODE"
echo "  /relatorio?start=...: HTTP $REL_CODE"

ADMIN_HTML=$(curl -s -b "$CJAR" 'https://produtividade.viaxis.tech/admin?tab=tipos')
REL_HTML=$(curl -s -b "$CJAR" 'https://produtividade.viaxis.tech/relatorio?start=2026-08-01&end=2026-08-31')
echo "  admin DS: $(echo "$ADMIN_HTML" | grep -c 'data-system="viasset"')"
echo "  relatorio DS: $(echo "$REL_HTML" | grep -c 'data-system="viasset"')"
echo "  relatorio toggle: $(echo "$REL_HTML" | grep -c 'window.toggleTheme = toggleTheme;')"
echo "  relatorio chartFont: $(echo "$REL_HTML" | grep -c 'function chartFont(){ return { family:')"

echo "=== Concluido ==="
echo "Backup: $BKP_DIR"
echo "URL: https://produtividade.viaxis.tech/admin"
echo "URL: https://produtividade.viaxis.tech/relatorio?start=2026-08-01&end=2026-08-31"
