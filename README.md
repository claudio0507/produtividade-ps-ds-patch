# Patch DS VIAXIS — Produtividade PS

Patch pronto para aplicar o design system VIAXIS v1.0.0
na aplicação https://produtividade.viaxis.tech/.

Origem: https://github.com/claudio0507/ds-viaxis-ui

## Conteúdo

- `produtividade-ps-ds-viaxis.tar.gz` — pacote com 5 templates corrigidos
- `apply-ds-viaxis.sh` — script de deploy com backup automático

## Instalação no VPS Hostinger (srv1759592)

```bash
cd /opt/produtividade-ps
wget -O /tmp/patch.tar.gz https://github.com/claudio0507/produtividade-ps-ds-patch/raw/main/produtividade-ps-ds-viaxis.tar.gz
wget -O /tmp/apply.sh https://github.com/claudio0507/produtividade-ps-ds-patch/raw/main/apply-ds-viaxis.sh
chmod +x /tmp/apply.sh
APP_DIR=/opt/produtividade-ps /tmp/apply.sh
```

## O que muda

- `data-system="viasset"` (acento verde #2BB673) no `<html>`
- `data-theme` com paridade total (light/dark)
- Tipografia nativa (Segoe UI + Consolas) — sem webfont
- 164 tokens do DS oficial inlinados em `base.html`
- 4 sistemas disponíveis via `data-system` (viaxis/viasign/viafab/viasset)

## Reversão

O backup fica em `/tmp/produtividade-ps-backup-<timestamp>/templates/`.
