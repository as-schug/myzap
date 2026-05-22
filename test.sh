#! /bin/sh
#
# test.sh - cliente de teste da API MYZAP
#
# Uso:
#   ./test.sh [-s SESSION] [-c CMD] [-h HOST] [-n NUMBER] [-m TEXT]
#             [-k SESSIONKEY] [-t TIMEOUT]
#
# Timeout:
#   - Se -t for informado, esse valor vai no POST.
#   - Se NÃO for informado, o script lê do session.js (se existir).
#   - Se nem isso, manda "timeout":null  -> o servidor decide (fallback do .env).

if [ -f ".env" ]; then
  . "./.env"
fi
if [ -f "myzap/.env" ]; then
  . myzap/.env
fi

# ============================================================================
# PARSE DOS ARGUMENTOS
# ============================================================================

while [ $# -gt 0 ]; do
  case "$1" in
    -k | --sessionkey )
      SESSIONKEY="$2"
      shift 2
      ;;
    -h | --host )
      host="$2"
      shift 2
      ;;
    -s | --session )
      SESSION="$2"
      shift 2
      ;;
    -c | --cmd | --command )
      CMD="$2"
      shift 2
      ;;
    -n | --number | -p | --phone )
      NUMBER="$2"
      shift 2
      ;;
    -t | --timeout )
      _TIMEOUT="$2"
      shift 2
      ;;
    -m | --message )
      TEXT="$2"
      shift 2
      ;;
    * )
      echo "Argumento inválido: [$1]"
      exit 1
      ;;
  esac
done

# ============================================================================
# DEFAULTS
# ============================================================================

if [ -z "$SESSION" ]; then
  ls -l tokens/
  SESSION='test'
else
  SESSION=$(basename "$SESSION")
fi

if [ -z "$CMD" ]; then
  CMD=SessionState
fi

if [ -z "$host" ]; then
  host="$HOST"
fi

# ============================================================================
# LEITURA DO session.js (se existir)
# ============================================================================

ARQ="./tokens/$SESSION/session.js"

if [ -f "$ARQ" ]; then
  if [ -z "$SESSIONKEY" ]; then
    SESSIONKEY=$(jq -r .sessionkey "$ARQ")
  fi
  MYWHSTATUS=$(jq -r .wh_status "$ARQ")
  MYWHMESSAGE=$(jq -r .wh_message "$ARQ")
  MYWHQRCODE=$(jq -r .wh_qrcode "$ARQ")
  MYWHCONNECT=$(jq -r .wh_connect "$ARQ")
  if [ -z "$TOKEN" ]; then
    TOKEN=$(jq -r .apitoken "$ARQ")
  fi
  # NOTA: o timeout NÃO é lido do session.js de propósito.
  # Comportamento desejado: por padrão deixar o servidor decidir (fallback .env).
  # Ler do JSON aqui criava auto-alimentação: o valor gravado voltava a ser
  # reenviado, perpetuando-se sem fonte externa real. Use -t para forçar.
  #
  # Se algum dia precisar do comportamento antigo (reusar timeout gravado),
  # basta descomentar o bloco abaixo:
  #
  # if [ -z "$_TIMEOUT" ]; then
  #   _TIMEOUT=$(jq -r .timeout "$ARQ")
  # fi
fi

# ============================================================================
# NORMALIZAÇÃO DO TIMEOUT
# ============================================================================
#
# _TIMEOUT pode estar:
#   - vazio        -> usuário não passou -t  -> manda null (servidor decide)
#   - número       -> usuário passou -t      -> manda o número
#   - "null"       -> só se o bloco de leitura do JSON acima for reativado
#                     (jq retorna a string "null" p/ campo ausente) -> manda null

if [ -z "$_TIMEOUT" ] || [ "$_TIMEOUT" = "null" ]; then
  _TIMEOUT=null
fi

# ============================================================================
# SESSIONKEY FALLBACK
# ============================================================================

if [ -z "$SESSIONKEY" ]; then
  SESSIONKEY=$(echo -n "$SESSION" "$SHAKEY" | sha512sum | sha256sum | base32 -w 0)
fi

# ============================================================================
# EXECUÇÃO
# ============================================================================

echo "Session: $SESSION"
echo "Using TOKEN: $TOKEN"
echo "Using Session Key: [$SESSIONKEY]"
echo "Using timeout: $_TIMEOUT"

curl -X POST -H 'Content-Type: application/json' \
  -k -m 60 \
  -H "sessionkey: $SESSIONKEY" \
  -H "apitoken: $TOKEN" \
  -d "{\"session\": \"$SESSION\",\"wh_status\":\"$MYWHSTATUS\",\"wh_message\":\"$MYWHMESSAGE\",\"wh_qrcode\":\"$MYWHQRCODE\",\"wh_connect\":\"$MYWHCONNECT\", \"number\": \"$NUMBER\", \"timeout\":$_TIMEOUT}" \
  "$host/$CMD"

echo ""
echo "========================="
