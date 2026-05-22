#!/bin/bash
#
# update-myzap-containers.sh
#
# Atualiza os containers MYZAP (npm install + npm update) e roda as limpezas
# associadas (npm cache, versões antigas do Puppeteer, files-received antigos).
#
# Ordem importa:
#   1. npm install / update — pode baixar nova versão do Chrome via Puppeteer
#   2. npm cache clean      — limpa cache npm (pode liberar GBs)
#   3. cleanup puppeteer    — apaga versões antigas do Chrome (mantém a recém-baixada)
#   4. cleanup files-recv   — apaga arquivos > 7 dias (lixo de mídia WhatsApp)
#   5. restart              — consolida o estado limpo
#
# Sem `set -e`: se algum container falhar, o loop continua com os outros
# (registra a falha no log e segue, em vez de parar no primeiro erro).

MODULOS="MYZAP-MAIN MYZAP-MAIN-WEB01 MYZAP-MAIN-WEB02 MYZAP-MAIN-WEB03 MYZAP-MAIN-WEB04 MYZAP-MAIN-WEB05"

echo "============================================"
echo "Início: $(date -Iseconds)"
echo "Disco antes:"
df -h /
echo "============================================"
echo ""

for i in $MODULOS; do
    echo "============================================"
    echo "Processando $i"
    echo "============================================"

    echo ">> docker start"
    docker start "$i"
    sleep 2

    echo ">> npm install"
    docker exec -i "$i" npm install

    echo ">> npm update"
    docker exec -i "$i" npm update

    echo ">> npm cache clean"
    docker exec -i "$i" npm cache clean --force

    echo ">> cleanup puppeteer versions"
    /usr/local/bin/cleanup-puppeteer-versions.sh --apply "$i"

    echo ">> cleanup files-received (> 7 dias)"
    /usr/local/bin/cleanup-files-received.sh --apply --days 7 "$i"

    echo ">> restart"
    docker stop "$i"
    docker start "$i"

    echo ""
done

echo "============================================"
echo "Fim: $(date -Iseconds)"
echo "Disco depois:"
df -h /
echo "============================================"

