 #! /bin/sh
 
# curl -X POST -H "Content-Type: application/json" -d '{"a":10}' "http://127.0.0.1:3333/webhook?session=xx&event=teste"

if [ -f ".env" ]
then
  . ./.env
fi

if [ -f "myzap/.env" ]
then
   . myzap/.env
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -a | --apitoken )
      APITOKEN="$2"
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
    * )
    echo "Invalid argument [$2]"SESSION="$1"
    exit 1
    ;;
  esac
done


#exit
#SESSION="$1"

if [ -z "$SESSION" ]
then
  SESSION='test'
else
  SESSION=$(basename "$SESSION")
fi

#CMD="$2"
if [ -z "$CMD" ]
then
   CMD=SessionState
fi   

#host="$3"
if [ -z "$host" ]
then
  host="$HOST"
fi


ARQ="./tokens/$SESSION/session.cfg" 
if [ -f $ARQ ]
then
  . $ARQ
else 
  ARQ="../tokens/$SESSION/session.cfg" 
  if [ -f $ARQ ]
  then
    . $ARQ
  fi 
fi  

if [ -z "$APITOKEN" ]
then
  APITOKEN=$MYSESSIONKEY
  if [ -z "$APITOKEN" ]
  then
    APITOKEN=$(echo -n "$SESSION" "$SHAKEY"|sha512sum|sha256sum|base32 -w 0)
  fi
fi  

echo "Using TOKEN: $TOKEN"

curl -X POST -H 'Content-Type: application/json' \
                  -k -m 60 \
                  -H "sessionkey: $APITOKEN" \
                  -H "apitoken: $TOKEN" -d "{\"session\": \"$SESSION\",\"wh_status\":\"$MYWHSTATUS\",\"wh_message\":\"$MYWHMESSAGE\",\"wh_qrcode\":\"$MYWHQRCODE\",\"wh_connect\":\"$MYWHCONNECT\"}" \
		  $host/$CMD
								

ls -l tokens/
									
									
									
