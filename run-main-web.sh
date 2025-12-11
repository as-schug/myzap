#! /bin/bash

MODULO=MYZAP
if [ -f /etc/terasoft.conf ]
then
  . /etc/terasoft.conf
fi

if [ -z "$RAIZ" ]
then
   echo definir a variavel RAIZ
   exit 1
fi

if [ -z "$*" ]
then
   ARGS=-d
fi



#docker build  -t myzap .

/usr/bin/docker start $*  $MODULO-MAIN-WEB || \
   /usr/bin/docker run $ARGS --name $MODULO-MAIN-WEB \
   -v $RAIZ/data/$MODULO/MAIN-WEB/tokens:/usr/src/app/tokens \
   --net $NET \
   --ip $IP.24 \
   myzap


