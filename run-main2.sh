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

/usr/bin/docker start $*  $MODULO-MAIN2 || \
   /usr/bin/docker run $ARGS --name $MODULO-MAIN2 -p 3336:3333 \
   -v $RAIZ/data/$MODULO/MAIN2/tokens:/usr/src/app/tokens \
   --net customnet \
   --ip 172.18.0.23 \
   myzap


