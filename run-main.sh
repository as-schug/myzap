#! /bin/bash

MODULO=MYZAP
SUBMODULO=MAIN

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

/usr/bin/docker start $*  $MODULO-$SUBMODULO || \
   /usr/bin/docker run $ARGS --name $MODULO-$SUBMODULO \
   -p 3500:3333 \
   -v $RAIZ/data/$MODULO/$SUBMODULO/tokens:/usr/src/app/tokens \
   --net $NET \
   --ip $IP.30 \
   myzap-web


