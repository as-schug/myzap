#! /bin/bash

# Instancia de TESTE do acesso direto pelo IP (rede criada por cria-rede-lan.sh; ver docs/REDE-LAN.md).
# Sem -p: o acesso e' direto em $IP.20:3333. Tokens proprios (nao usa os do COMUM).
# Atencao: usa o mesmo final .20 do run-test.sh (desativado no .222).

MODULO=MYZAP
SUBMODULO=LANTEST

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

/usr/bin/docker start $*  $MODULO-$SUBMODULO || \
   /usr/bin/docker run $ARGS --name $MODULO-$SUBMODULO \
   -v $RAIZ/data/$MODULO/$SUBMODULO/tokens:/usr/src/app/tokens \
   --net $NET \
   --ip $IP.20 \
   myzap-web
