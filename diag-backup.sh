#!/bin/bash
# Diagnostico: compara backup vs estado atual (depois do patch)
# Roda no VPS como root

BKP=/tmp/produtividade-ps-backup-20260806-132858/templates
CUR=/opt/produtividade-ps/templates

echo "=== TEMPLATES NO BACKUP (estado ANTES do patch) ==="
ls -la $BKP/

echo
echo "=== TEMPLATES ATUAIS (estado DEPOIS do patch) ==="
ls -la $CUR/

echo
echo "=== OCORRENCIAS DE 'relat' / 'gerar' / 'export' / 'pdf' / 'xlsx' / 'csv' NO BACKUP ==="
for f in $BKP/*.html; do
  HITS=$(grep -iE "relat|gerar|export|pdf|xlsx|csv|download|/relatorio|btn-gerar" "$f" 2>/dev/null | wc -l)
  if [ "$HITS" -gt 0 ]; then
    echo
    echo ">>> $(basename $f) ($HITS ocorrencias):"
    grep -inE "relat|gerar|export|pdf|xlsx|csv|download|/relatorio|btn-gerar" "$f" | head -20
  fi
done

echo
echo "=== OCORRENCIAS NO ESTADO ATUAL ==="
for f in $CUR/*.html; do
  HITS=$(grep -iE "relat|gerar|export|pdf|xlsx|csv|download|/relatorio|btn-gerar" "$f" 2>/dev/null | wc -l)
  if [ "$HITS" -gt 0 ]; then
    echo
    echo ">>> $(basename $f) ($HITS ocorrencias):"
    grep -inE "relat|gerar|export|pdf|xlsx|csv|download|/relatorio|btn-gerar" "$f" | head -20
  fi
done

echo
echo "=== DIFF: backup vs atual (apenas arquivos que diferem) ==="
for f in $BKP/*.html; do
  NAME=$(basename $f)
  if ! diff -q "$f" "$CUR/$NAME" >/dev/null 2>&1; then
    echo
    echo ">>> $NAME difere:"
    diff -u "$f" "$CUR/$NAME" | head -80
    echo "(...)"
  fi
done
