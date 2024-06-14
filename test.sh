 #! /bin/sh
 
if [ -f ".env" ]
then
  . "./.env"
fi

if [ -f "myzap/.env" ]
then
   . myzap/.env
fi

#TIMEOUT=null

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
    echo "Invalid argument [$2]"SESSION="$1"
    exit 1
    ;;
  esac
done

if [ -z "$SESSION" ]
then
 
   ls -l tokens/
  
  SESSION='test'
else
  SESSION=$(basename "$SESSION")
fi

if [ -z "$CMD" ]
then
   CMD=SessionState
fi   

if [ -z "$host" ]
then
  host="$HOST"
fi

ARQ="./tokens/$SESSION/session.js"
if [ -f $ARQ ]
then
  if [ -z "$SESSIONKEY" ]
  then
    SESSIONKEY=$(cat $ARQ| jq -r .sessionkey)
  fi
  MYWHSTATUS=$(cat $ARQ| jq -r .wh_status)
  MYWHMESSAGE=$(cat $ARQ| jq -r .wh_message)
  MYWHQRCODE=$(cat $ARQ| jq -r .wh_qrcode)
  MYWHCONNECT=$(cat $ARQ| jq -r .wh_connect) 
  if [ -z "$TOKEN" ]
  then
    TOKEN=$(cat $ARQ| jq -r .apitoken)    
  fi
  if [ -z "$_TIMEOUT" ]
  then
     _TIMEOUT=$(cat $ARQ| jq -r .timeout)
  fi
fi

if [ -z "$_TIMEOUT" ]
then
  _TIMEOUT=null
fi

if [ -z "$SESSIONKEY" ]
then
  SESSIONKEY=$(echo -n "$SESSION" "$SHAKEY"|sha512sum|sha256sum|base32 -w 0)
fi  

echo "Session: $SESSION"
echo "Using TOKEN: $TOKEN" 
echo "Usign Session Key: [$SESSIONKEY]"
echo "Using timout of $_TIMEOUT secs"

curl -X POST -H 'Content-Type: application/json' \
                  -k -m 60 \
                  -H "sessionkey: $SESSIONKEY" \
                  -H "apitoken: $TOKEN" -d "{\"session\": \"$SESSION\",\"wh_status\":\"$MYWHSTATUS\",\"wh_message\":\"$MYWHMESSAGE\",\"wh_qrcode\":\"$MYWHQRCODE\",\"wh_connect\":\"$MYWHCONNECT\", \"number\": \"$NUMBER\", \"timeout\":$_TIMEOUT}" \
		  $host/$CMD
								
echo "========================="

#ls -l tokens/

