#!/bin/bash
# Aplica DS VIAXIS v1.0.0 no Produtividade PS - patch v4
# - Sobrescreve 6 templates (incluindo relatorio.html)
# - Valida 9+ marcadores antes de aplicar
# - Reversível via backup

set -e

APP_DIR=${APP_DIR:-/opt/produtividade-ps}
TAR_URL=https://github.com/claudio0507/produtividade-ps-ds-patch/raw/main/produtividade-ps-ds-viaxis-v4.tar.gz
BKP_DIR=/tmp/produtividade-ps-backup-v4-$(date +%Y%m%d-%H%M%S)

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
wget -q "$TAR_URL" -O ds-viaxis-v4.tar.gz
tar -xzf ds-viaxis-v4.tar.gz
ls -la templates/

echo
echo "=== 4. Validacoes ==="
FAILED=0

check() {
  if [ "$1" -eq 0 ]; then
    echo "  [OK] $2"
  else
    echo "  [FAIL] $2"
    FAILED=1
  fi
}

# 4.1. base.html com DS
grep -q 'data-system="viasset"' templates/base.html; check $? "base.html: data-system=viasset"
grep -q '#2BB673' templates/base.html; check $? "base.html: acento VIASSET (#2BB673)"
grep -q 'Segoe UI' templates/base.html; check $? "base.html: tipografia nativa (Segoe UI)"

# 4.2. relatorio.html com DS
grep -q 'data-system="viasset"' templates/relatorio.html; check $? "relatorio.html: data-system=viasset"
grep -q '#2BB673' templates/relatorio.html; check $? "relatorio.html: acento VIASSET"
grep -q 'Segoe UI' templates/relatorio.html; check $? "relatorio.html: tipografia nativa"

# 4.3. dashboard
grep -q '/relatorio?start=' templates/dashboard.html; check $? "dashboard.html: botao de relatorio"
grep -q 'data-system="viasset"' templates/dashboard.html; check $? "dashboard.html: data-system=viasset"

# 4.4. admin: 5 abas
TABS=$(grep -c "tab-btn.*tab==" templates/admin.html)
[ "$TABS" -ge 5 ]; check $? "admin.html: 5 abas (got $TABS)"

# 4.5. Sem webfonts
! grep -q 'fonts.googleapis.com' templates/*.html 2>/dev/null
check $? "nenhum template com webfonts Google"

# 4.6. Sem emojis
! grep -lP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' templates/*.html 2>/dev/null | grep -q .
check $? "nenhum template com emoji"

# 4.7. Sem vars CSS legadas
! grep -lE 'var\(--red\)|var\(--green\)|var\(--text[2-9]\)' templates/*.html 2>/dev/null | grep -q .
check $? "nenhum template com vars CSS legadas (--red/--green/--text)"

# 4.8. Jinja valido
python3 -c "
import jinja2, os
errs = 0
for f in sorted(os.listdir('templates')):
    if not f.endswith('.html'):
        continue
    try:
        jinja2.Environment().parse(open('templates/'+f).read())
    except jinja2.TemplateSyntaxError as e:
        print(f'    {f}: {e}')
        errs += 1
exit(errs)
" > /tmp/jinja-out.txt 2>&1
JERR=$?
if [ $JERR -eq 0 ]; then
  echo "  [OK] sintaxe Jinja valida em todos os 6 templates"
else
  echo "  [FAIL] Jinja:"
  cat /tmp/jinja-out.txt
  FAILED=1
fi

# 4.9. relatorio.html: graficos (Chart.js) presentes
grep -q 'chart.js' templates/relatorio.html; check $? "relatorio.html: Chart.js carregado"
grep -q 'datas_json' templates/relatorio.html; check $? "relatorio.html: var datas_json (Jinja)"
grep -q 'obras_json' templates/relatorio.html; check $? "relatorio.html: var obras_json (Jinja)"
grep -q '{% for r in ranking %}' templates/relatorio.html; check $? "relatorio.html: loop ranking"
grep -q '{% for insight in insights %}' templates/relatorio.html; check $? "relatorio.html: loop insights"

if [ "$FAILED" -gt 0 ]; then
  echo
  echo "=== ABORTANDO: $FAILED validacao(oes) falharam ==="
  echo "Templates NAO foram sobrescritos. Backup em $BKP_DIR"
  exit 1
fi

echo
echo "=== 5. Sobrescreve templates ==="
for f in base.html dashboard.html admin.html login.html apontamentos.html relatorio.html; do
  cp -f "templates/$f" "$APP_DIR/templates/$f"
  SIZE=$(stat -c%s "$APP_DIR/templates/$f")
  echo "  [OK] $f ($SIZE bytes)"
done

echo
echo "=== 6. Reinicia servico ==="
systemctl restart produtividade-ps && echo "  [OK] reiniciado" || echo "  [WARN] servico nao reiniciou"

echo
echo "=== 7. Verificacao pos-deploy ==="
sleep 2
for path in /login /dashboard /admin /apontamentos /relatorio; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://produtividade.viaxis.tech$path")
  echo "  GET $path: HTTP $CODE"
done

echo
echo "=== Concluido ==="
echo "URL: https://produtividade.viaxis.tech/login"
echo "URL: https://produtividade.viaxis.tech/dashboard (autenticado)"
echo "URL: https://produtividade.viaxis.tech/relatorio (autenticado)"
echo "Backup: $BKP_DIR"
echo "Reversao: cp -rf $BKP_DIR/templates/* $APP_DIR/templates/ && systemctl restart produtividade-ps"
