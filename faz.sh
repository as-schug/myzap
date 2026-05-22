#! /bin/bash
#
# faz.sh - entrypoint do container MYZAP
#
# Carrega o .env, faz manutenção da pasta webhook, opcionalmente limpa
# as sessões antigas (start limpo), e entra no loop de execução da app.

# Carrega .env para ler a flag CLEAN_START (e demais variáveis).
[ -f .env ] && . ./.env

# ----------------------------------------------------------------------------
# Manutenção da pasta webhook
# ----------------------------------------------------------------------------
chmod 777 webhook
chmod 777 webhook/*
find webhook -type f -ctime +10 -exec chmod 666 {} \; -print
find webhook -empty -delete -ctime +10 -print

# ----------------------------------------------------------------------------
# Start limpo (opcional)
#
# Apaga o conteúdo de tokens/ ANTES de subir a app. Resolve o problema de
# sessao antiga incompativel travando o browser ao iniciar uma instancia
# zerada (build novo / cobaia).
#
# Ativado APENAS por CLEAN_START=true no .env.
#
# ATENCAO: em producao NAO use esta flag. Apagar tokens/ faz todos os
# clientes perderem a sessao e precisarem re-escanear o QR code.
# Sem a flag (ausente ou qualquer valor != "true"), nada e apagado.
# ----------------------------------------------------------------------------
if [ "$CLEAN_START" = "true" ]; then
  echo '============================================'
  echo 'CLEAN_START=true - apagando sessoes antigas'
  echo '============================================'
  rm -rf tokens/*
  echo 'tokens/ limpo. Subindo instancia zerada.'
else
  echo 'CLEAN_START inativo - sessoes preservadas.'
fi

# ----------------------------------------------------------------------------
# Loop de execucao
# ----------------------------------------------------------------------------
while [ true ]
do
  echo 'Updating...'
  #npm install
  #npm update
  echo 'Starting...'
#  sleep 10
  chmod 777 tokens
  npm start
done
