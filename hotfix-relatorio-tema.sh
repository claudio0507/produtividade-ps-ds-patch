#!/bin/bash
set -euo pipefail
APP_DIR=${APP_DIR:-/opt/produtividade-ps}
RESTART_CMD=${RESTART_CMD:-"systemctl restart produtividade-ps"}
BKP_DIR=/tmp/produtividade-ps-hotfix-$(date +%Y%m%d-%H%M%S)

REL="$APP_DIR/templates/relatorio.html"
BASE="$APP_DIR/templates/base.html"
[ -f "$REL" ] && [ -f "$BASE" ]

mkdir -p "$BKP_DIR"
cp "$REL" "$BKP_DIR/relatorio.html"
cp "$BASE" "$BKP_DIR/base.html"
echo "Backup: $BKP_DIR"

APP_DIR="$APP_DIR" python3 - <<'PY'
from pathlib import Path
import os

root = Path(os.environ['APP_DIR']) / 'templates'
rel_path = root / 'relatorio.html'
base_path = root / 'base.html'
rel = rel_path.read_text()
base = base_path.read_text()

bad = "family: ''Segoe UI',system-ui,-apple-system,sans-serif', size: 10"
good = """family: "'Segoe UI',system-ui,-apple-system,sans-serif", size: 10"""
if bad in rel:
    rel = rel.replace(bad, good, 1)
elif good not in rel:
    raise SystemExit('chartFont desconhecido: abortado sem alterar o arquivo')

anchor = """function chartFont(){ return { family: "'Segoe UI',system-ui,-apple-system,sans-serif", size: 10 }; }"""
if anchor not in rel:
    raise SystemExit('anchor chartFont nao localizado: abortado sem alterar o arquivo')
if 'window.toggleTheme = toggleTheme;' not in rel:
    rel = rel.replace(anchor, anchor + '\nwindow.toggleTheme = toggleTheme;', 1)

if 'window.toggleTheme = function' not in base:
    theme_script = """<script>
window.toggleTheme = function () {
  const root = document.documentElement;
  const next = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
  root.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
  const label = document.getElementById('themeLabel');
  if (label) label.textContent = next === 'dark' ? 'Tema Claro' : 'Tema Escuro';
};
</script>
"""
    if '</body>' not in base:
        raise SystemExit('base.html sem </body>: abortado sem alterar o arquivo')
    base = base.replace('</body>', theme_script + '</body>', 1)

rel_path.write_text(rel)
base_path.write_text(base)

assert bad not in rel
assert good in rel
assert 'window.toggleTheme = toggleTheme;' in rel
assert 'window.toggleTheme = function' in base
print('OK: chartFont corrigido; tema global habilitado')
PY

eval "$RESTART_CMD"
if command -v systemctl >/dev/null 2>&1 && [[ "$RESTART_CMD" == systemctl* ]]; then
  systemctl is-active --quiet produtividade-ps
fi

echo "OK: aplicacao reiniciada"
echo "Backup: $BKP_DIR"
