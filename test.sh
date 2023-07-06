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

SESSION="$1"

if [ -z "$SESSION" ]
then
  SESSION='test'
else
  SESSION=$(basename "$SESSION")
fi

CMD="$2"
if [ -z "$CMD" ]
then
   CMD=start
fi   

ARQ="./tokens/$SESSION/session.cfg" 
if [ -f $ARQ ]
then
  . $ARQ
fi  

APITOKEN=$MYSESSIONKEY
if [ -z "$MYSESSIONKEY" ]
then
  APITOKEN=$(echo -n "$SESSION" "$SHAKEY"|sha512sum|sha256sum|base32 -w 0)
fi

echo "Using TOKEN: $TOKEN"

curl -X POST -H 'Content-Type: application/json' \
                  -m 60 \
                  -H "sessionkey: $APITOKEN" \
                  -H "apitoken: $TOKEN" -d "{\"session\": \"$SESSION\",\"wh_status\":\"$MYWHSTATUS\",\"wh_message\":\"$MYWHMESSAGE\",\"wh_qrcode\":\"$MYWHQRCODE\",\"wh_connect\":\"$MYWHCONNECT\"}" \
		  $HOST/$CMD
								

ls -l tokens/
									
									
									
