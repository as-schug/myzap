#! /bin/bash

MODULO=myzap
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

/usr/bin/docker start $*  $MODULO || \
   /usr/bin/docker run $ARGS --name $MODULO -p 3334:3333 -p 3333:3333 -v $RAIZ/data/$MODULO/tokens:/usr/src/app/tokens myzap


