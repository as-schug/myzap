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

/usr/bin/docker start $*  $MODULO-TEST || \
   /usr/bin/docker run $ARGS --name $MODULO-TEST -p 3335:3333 -v $RAIZ/data/$MODULO/TEST/tokens:/usr/src/app/tokens myzap


